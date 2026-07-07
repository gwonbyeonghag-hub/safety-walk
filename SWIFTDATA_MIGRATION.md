# SWIFTDATA_MIGRATION.md — SafetyWalk

SwiftData schema reference + migration policy.
This is a **policy/reference document**; the actual migration code lives in
`SafetyWalkCore/Sources/SafetyWalkCore/Migration/` (`SchemaV1`, `SchemaV2`,
`SafetyWalkMigrationPlan`). WO-3 introduced the first `VersionedSchema` +
`SchemaMigrationPlan` — every model change from here on must extend that plan
(add `SchemaV3`, a new migration stage) rather than editing the live models in place.

Last verified against source: 2026-07-07 (WO-3 — CloudKit sync).

---

## 1. Current schema (SchemaV2 — CloudKit, WO-3)

7 `@Model` types, all declared in `SafetyWalkCore` (single source of truth for both
apps) and registered via `Schema(versionedSchema: SchemaV2.self)`:

- iOS: `SafetyWalkApp.swift` — `SafetyWalkApp.modelContainer`
- macOS: `SafetyWalkMac/MacModelContainer.swift` — `MacModelContainer.shared`
  (DEBUG stays an in-memory seeded store, account-independent per WO-4; Release
  matches iOS)

Both apps' Release configuration use the same CloudKit container:

```swift
ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.com.gwonbyeonghag.safetywalk"))
try ModelContainer(for: schema, migrationPlan: SafetyWalkMigrationPlan.self, configurations: configuration)
```

CloudKit's schema constraints (why every field below has a default or is optional,
and why relationships are optional): every attribute must be optional **or** have a
declaration default; every to-many relationship must be optional; `@Attribute(.unique)`
is forbidden. These were audited and retrofitted in WO-3 — see §3 for what still
counts as lightweight vs. requires-a-new-schema-version going forward.

### Fields (exact, from `SafetyWalkCore/Sources/SafetyWalkCore/`)

| Model | Field | Type | Notes |
|---|---|---|---|
| **Site** | id | `UUID = UUID()` | not `@Attribute(.unique)` |
| | name | `String = ""` | |
| | address | `String?` | optional |
| | createdAt | `Date = Date()` | |
| | areas | `[Area]?` | `@Relationship(deleteRule: .cascade, inverse: \Area.site)`, optional (CloudKit) |
| **Area** | id | `UUID = UUID()` | |
| | name | `String = ""` | |
| | siteId | `UUID = UUID()` | plain UUID; **still the source of truth for lookups** (intentional, §1.1) |
| | site | `Site?` | CloudKit-required inverse of `Site.areas` only; not read by app code |
| **Inspection** | id | `UUID = UUID()` | |
| | siteId | `UUID = UUID()` | plain UUID, not a relationship |
| | areaId | `UUID?` | plain UUID, not a relationship |
| | siteName / areaName | `String = ""` / `String?` | **denormalized** (see §1.1) |
| | inspectorName | `String = ""` | |
| | startedAt | `Date = Date()` | |
| | completedAt | `Date?` | |
| | status | `InspectionStatus = .inProgress` | enum, String raw |
| | templateId | `String = ""` | |
| | items | `[ChecklistItem]?` | `@Relationship(deleteRule: .cascade, inverse: \ChecklistItem.inspection)`, optional |
| | hazards | `[Hazard]?` | `@Relationship(deleteRule: .cascade, inverse: \Hazard.inspection)`, optional |
| **ChecklistItem** | id | `UUID = UUID()` | |
| | inspectionId | `UUID = UUID()` | denormalized id of owner; source of truth for lookups |
| | templateItemId | `String = ""` | |
| | title / category | `String = ""` / `String = ""` | copied from template at creation |
| | result | `ChecklistItemResult = .unchecked` | enum, String raw |
| | note | `String?` | optional |
| | photoData | `Data?`, `@Attribute(.externalStorage)` | CloudKit `CKAsset`; replaces `photoPath` (§4) |
| | linkedHazardId | `UUID?` | optional |
| | sortOrder | `Int = 0` | |
| | inspection | `Inspection?` | CloudKit-required inverse of `Inspection.items`; not read by app code |
| **Hazard** | id | `UUID = UUID()` | |
| | inspectionId | `UUID?` | **optional → standalone hazard** (§5); source of truth for lookups |
| | siteId | `UUID = UUID()` | plain UUID |
| | location | `String = ""` | |
| | type | `HazardType = .general` | enum, String raw |
| | riskLevel | `RiskLevel = .low` | enum, String raw |
| | hazardDescription | `String = ""` | named to avoid `CustomStringConvertible.description` |
| | photoData | `Data?`, `@Attribute(.externalStorage)` | CloudKit `CKAsset`; `nil` = no photo (§4) |
| | correctiveActionStatus | `CorrectiveActionStatus = .notStarted` | enum, String raw |
| | createdAt / updatedAt | `Date = Date()` / `Date = Date()` | |
| | inspection | `Inspection?` | CloudKit-required inverse of `Inspection.hazards`; **must stay `nil`** for a standalone hazard, mirroring `inspectionId == nil` (§5) |
| **RiskAssessment** (WO-2, defaults added WO-3) | items | `[RiskAssessmentItem]?` | `@Relationship(deleteRule: .cascade, inverse: \RiskAssessmentItem.riskAssessment)` — only field that changed in WO-3; rest unchanged since WO-2 |
| **RiskAssessmentItem** (WO-2) | riskAssessment | `RiskAssessment?` | CloudKit-required inverse of `RiskAssessment.items` (new in WO-3); not read by app code — containment in the array is the source of truth |

### Enums (all `String` raw value — `SafetyWalkCore/Sources/SafetyWalkCore/Enums.swift`)

```
ChecklistItemResult : pass, fail, notApplicable, unchecked
RiskLevel           : low, medium, high
CorrectiveActionStatus : notStarted, inProgress, completed
InspectionStatus    : inProgress, completed
RegionProfile       : korea, global        (UserDefaults, not a model field)
HazardType          : fallRisk, electrical, fire, chemical, general, other
RiskAssessmentKind, RiskAssessmentMethod (WO-2) — see DOMAIN_TERMS.md
```

### 1.1 Why fields are denormalized

`Inspection.siteName` / `areaName` and `Hazard`/`ChecklistItem` carrying ids
(not relationships) is **deliberate**: deleting a `Site` (or `Area`) must **not**
cascade-wipe inspection/hazard **history**. Only `Site → areas`,
`Inspection → items`, and `Inspection → hazards` are real cascade relationships;
everything cross-entity is a stored `UUID` + a denormalized display string. Keep
this pattern — it is the data-integrity contract, not an oversight.

---

## 2. Storage / lifecycle policy (current behavior)

- **Container**: CloudKit-backed persistent store (`iCloud.com.gwonbyeonghag.safetywalk`,
  private database), versioned via `SchemaV2` + `SafetyWalkMigrationPlan`. Both apps
  point at the same container id, so a record created on either device syncs to the
  other under the same iCloud account. Push/remote-notification-driven background
  sync is out of scope for WO-3 (CloudKit sync only; real-time push is a follow-up) —
  sync happens when either app is foregrounded/active.
- **Offline-first preserved**: the full point-of-inspection workflow (site → area →
  checklist → hazard → risk assessment) still completes with no network — CloudKit is
  a sync layer on top of the local store, not a requirement for any screen to function.
- **App delete**: removes the whole container + the app sandbox — total wipe,
  OS-level. The CloudKit private database itself is untouched (survives reinstall,
  re-syncs on next sign-in).
- **로컬 데이터 초기화 (Settings → reset)** — `SettingsView.performReset()`:
  fetch-and-`delete` all `Inspection` (cascades items + in-inspection hazards),
  then all remaining `Hazard` (standalone), then all `Site` (cascades areas),
  `modelContext.save()`, then `PhotoStorageService.deleteAllEvidencePhotos()`
  (best-effort cleanup of any legacy pre-WO-3 photo files still on disk).
  **Does NOT touch UserDefaults** — see §6. Deletes propagate through CloudKit like
  any other change.
- **Photos**: live entirely as `photoData` on the row itself (`@Attribute(.externalStorage)`,
  synced as a `CKAsset`) — deleting a row deletes its photo automatically, no
  separate file-cleanup step needed (unlike the pre-WO-3 file-path scheme, §4).

---

## 3. Post-launch change classification

The app has real user data on-device now (WO-3 migrated it) — classify every
model change before merging:

### ✅ Lightweight-safe (SwiftData can infer; no new `VersionedSchema` needed)
- Add a **new optional** field (`T?`) to an existing model.
- Add a new field **with a declaration default** (existing rows get the default;
  a scalar field that was already non-optional with every row populated, gaining
  only a compile-time default, does not change the on-disk shape at all — this is
  how WO-3 added CloudKit-required defaults to `Site`/`Area`/`Inspection` etc.
  without a custom migration stage).
- Making a **to-many relationship** optional (`[T]` → `[T]?`) at the same property
  name — a to-many relationship has no physical "null" distinct from "empty" at
  the store level, so this is inferred too (how `areas`/`items`/`hazards` became
  CloudKit-safe in WO-3 without a rename).
- Add a brand-new `@Model` type (and register it in `SchemaV{N}.models`).
- Add a new enum **case** to a String-raw enum (old rows never hold it; new code
  must still handle all cases in `switch`).
- UI-only computed helpers / view code (no stored property change at all).

### ⚠️ Requires an explicit migration (bump `SchemaV{N+1}`, add a `MigrationStage`)
- Add a **non-optional** field **without** a default → old rows can't be decoded.
- **Rename** a property or `@Model` type (SwiftData sees drop+add → data loss
  unless mapped in a migration stage) — **including** a relationship's stored
  property name (its destination model's shape is baked into the class
  declaration, so any model with a relationship to a changed type needs its own
  versioned copy too — see how `SchemaV1.Inspection` had to be redeclared
  alongside `SchemaV1.ChecklistItem`/`SchemaV1.Hazard` even though `Inspection`'s
  own fields didn't change).
- **Delete** a property / model, or change a property's **type** (exactly what
  `photoPath: String` → `photoData: Data` was in WO-3).
- Change a **relationship** (add/remove, change `deleteRule`, change cardinality,
  add an inverse).
- Add `@Attribute(.unique)` to a field that has existing duplicate values.

**How to extend the plan**: add `SchemaV{N+1}` (redeclare only the models whose
stored shape — or a relationship destination's shape — actually changes; reuse
every other model directly from the live module if it's genuinely untouched by
the change — the reuse trick only saved a redeclaration for zero models in WO-3,
because adding the required relationship inverses touched every model's
relationship graph transitively; a change that doesn't touch relationships at
all, e.g. adding one new optional scalar field to a single model, would only
need that one model redeclared), add a `MigrationStage`
to `SafetyWalkMigrationPlan.stages`, and add `SchemaV{N+1}` to `.schemas`. Write a
test that seeds a store at the old version and reopens it through the plan
(see `SafetyWalkCoreTests/SchemaMigrationTests.swift`) before merging.

### ⛔ Prohibited (per CLAUDE.md / DOMAIN_TERMS.md)
- **Changing an enum `rawValue` string** (e.g. `notStarted` → `not_started`):
  every persisted row stores the raw string; changing it silently fails to
  decode old rows. Rename the Swift case only with a migration that rewrites
  stored values, and update DOMAIN_TERMS.md first.
- Renaming any domain term without updating DOMAIN_TERMS.md first.
- Changing model fields without explicit approval.

---

## 4. Evidence photos — `photoData` (WO-3; pre-WO-3 `photoPath` is migration-only history)

Evidence photos now live **on the row itself**: `ChecklistItem.photoData: Data?` /
`Hazard.photoData: Data?`, both `@Attribute(.externalStorage)` — SwiftData stores
them out-of-line on disk locally and mirrors them as a `CKAsset` under CloudKit.
`nil` means "no photo" (this replaced `ChecklistItem.photoPath: String?` and
`Hazard.photoPath: String` where `""` meant "no photo" — that sentinel is gone).

- **No separate file management**: deleting a row deletes its `photoData`
  automatically (cascade or direct delete) — there is no second "file on disk" to
  clean up, unlike the pre-WO-3 scheme. `InspectionDetailView.performDelete` no
  longer snapshots/deletes photo paths for this reason.
- **Compression**: `PhotoStorageService.data(from:)` resizes to ≤1024px longest
  side and JPEG-compresses, returning `Data` directly — no file is written.
  `PhotoStorageService.downsampled(_:maxDimension:)` decodes a memory-efficient
  thumbnail from already-in-memory `Data` (used by `InspectionExportService` when
  preloading many photos for a PDF export).
- **Legacy file access is migration-only**: `PhotoStorageService.loadLegacyData(relativePath:)`
  / `deleteLegacyFile(relativePath:)` read/remove files under the old
  `Documents/EvidencePhotos/<uuid>.jpg` scheme. The only caller is
  `SafetyWalkMigrationPlan`'s `SchemaV1`→`SchemaV2` stage, which reads each
  existing row's `photoPath` file into `photoData` and deletes the file once
  copied. Do not add new production call sites for these — they exist so the
  migration can run once against real on-disk data, not as an ongoing API.
- Missing legacy files during migration are tolerated (row keeps `photoData ==
  nil`, cosmetic gap, not a crash) — this can only happen if a file was already
  lost pre-migration (e.g. manually deleted from the sandbox).

---

## 5. Standalone Hazard + cascade cautions

- `Hazard.inspectionId` is **optional**. A standalone hazard (registered from the
  Hazards tab, not inside an inspection) has `inspectionId == nil` and is **not**
  a member of any `Inspection.hazards` relationship → it is **not** cascade-
  deleted when an inspection is deleted. Reset deletes it via the explicit
  "delete all remaining `Hazard`" pass.
- Any migration or new delete path must preserve this: **do not** make
  `inspectionId` non-optional, and **do not** convert `Inspection.hazards` into a
  rule that would orphan or wrongly cascade standalone hazards.
- `Inspection → items` and `Inspection → hazards` are `.cascade`: deleting an
  inspection deletes its checklist items and its *in-inspection* hazards. Changing
  these deleteRules is a ⚠️ migration **and** a behavior change — get approval.

---

## 6. UserDefaults vs SwiftData boundary

These live in **UserDefaults**, never SwiftData, and are intentionally **not**
cleared by 로컬 데이터 초기화:
`com.safetywalk.hasCompletedOnboarding`, `com.safetywalk.appearanceMode`,
`com.safetywalk.inspectorName`, and the selected `RegionProfile`
(`RegionProfileStore`). A schema migration touches SwiftData only; it must not
assume these are reset, and resetting data must keep these preferences intact
(documented behavior in the reset confirm copy).

---

## 7. "SwiftData schema impact" — per-PR checklist

Add this to any PR/task that edits `SafetyWalkCore/Sources/SafetyWalkCore/*.swift` models:

- [ ] Does this add/rename/delete a stored property, model, or relationship?
- [ ] If yes: is it lightweight-safe (§3 ✅) or does it need a new `SchemaV{N+1}` + `MigrationStage` (§3 ⚠️)?
- [ ] Are all enum `rawValue` strings unchanged? (changing them is ⛔)
- [ ] Are denormalized fields (§1.1) and `photoData` semantics (§4) preserved?
- [ ] Is `Hazard.inspectionId` still optional and standalone-safe (§5)?
- [ ] Is the change CloudKit-safe (every attribute optional-or-defaulted, every
      to-many relationship optional, **every relationship has an `inverse:`**
      — this last one is a runtime-only crash, not a compile error, and is easy
      to miss; the destination model needs a back-reference property even if
      no app code ever reads it — see §1's `Area.site`/`ChecklistItem.inspection`
      examples; no `@Attribute(.unique)`)?
- [ ] Did you write a `SchemaMigrationTests.swift`-style test seeding the OLD
      version and reopening through `SafetyWalkMigrationPlan` before merging?
- [ ] DOMAIN_TERMS.md updated if any term/enum changed?

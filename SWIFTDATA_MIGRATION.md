# SWIFTDATA_MIGRATION.md — SafetyWalk

SwiftData schema reference + post-launch migration policy.
This is a **policy/reference document**, not migration code. SafetyWalk currently
ships **no** `VersionedSchema` / `SchemaMigrationPlan` (it relies on SwiftData's
implicit lightweight inference). Before the **first model change made after App
Store release**, follow the policy below.

Last verified against source: 2026-06-18.

---

## 1. Current schema (the frozen baseline)

5 `@Model` types, registered in `SafetyWalkApp.swift`:

```swift
.modelContainer(for: [Site.self, Area.self, Inspection.self, ChecklistItem.self, Hazard.self])
```

Default container = **on-disk, persistent** (`default.store` in the app's
Application Support). No `ModelConfiguration` overrides, no CloudKit, no
app-group. The only in-memory container is in `HomeView`'s `#Preview`
(`inMemory: true`) — not production.

### Fields (exact, from `Models/`)

| Model | Field | Type | Notes |
|---|---|---|---|
| **Site** | id | `UUID` | not `@Attribute(.unique)` |
| | name | `String` | |
| | address | `String?` | optional |
| | createdAt | `Date` | |
| | areas | `[Area]` | `@Relationship(deleteRule: .cascade)` |
| **Area** | id | `UUID` | |
| | name | `String` | |
| | siteId | `UUID` | plain UUID, **no inverse relationship** (intentional) |
| **Inspection** | id | `UUID` | |
| | siteId / areaId | `UUID` / `UUID?` | plain UUIDs, **not** relationships |
| | siteName / areaName | `String` / `String?` | **denormalized** (see §1.1) |
| | inspectorName | `String` | |
| | startedAt / completedAt | `Date` / `Date?` | |
| | status | `InspectionStatus` | enum, String raw |
| | templateId | `String` | |
| | items | `[ChecklistItem]` | `@Relationship(deleteRule: .cascade)` |
| | hazards | `[Hazard]` | `@Relationship(deleteRule: .cascade)` |
| **ChecklistItem** | id | `UUID` | |
| | inspectionId | `UUID` | denormalized id of owner |
| | templateItemId | `String` | |
| | title / category | `String` / `String` | copied from template at creation |
| | result | `ChecklistItemResult` | enum, String raw |
| | note | `String?` | optional |
| | photoPath | `String?` | optional; relative path into EvidencePhotos (§4) |
| | linkedHazardId | `UUID?` | optional |
| | sortOrder | `Int` | |
| **Hazard** | id | `UUID` | |
| | inspectionId | `UUID?` | **optional → standalone hazard** (§5) |
| | siteId | `UUID` | plain UUID |
| | location | `String` | |
| | type | `HazardType` | enum, String raw |
| | riskLevel | `RiskLevel` | enum, String raw |
| | hazardDescription | `String` | named to avoid `CustomStringConvertible.description` |
| | photoPath | `String` | **non-optional**; may be `""` (no photo) |
| | correctiveActionStatus | `CorrectiveActionStatus` | enum, String raw |
| | createdAt / updatedAt | `Date` / `Date` | |

### Enums (all `String` raw value — `Models/Enums.swift`)

```
ChecklistItemResult : pass, fail, notApplicable, unchecked
RiskLevel           : low, medium, high
CorrectiveActionStatus : notStarted, inProgress, completed
InspectionStatus    : inProgress, completed
RegionProfile       : korea, global        (UserDefaults, not a model field)
HazardType          : fallRisk, electrical, fire, chemical, general, other
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

- **Container**: default persistent store, models listed above. No schema
  version identifier is declared, so SwiftData performs **implicit lightweight
  migration** between launches (works only for additive/inferable changes).
- **App delete**: removes the whole container + the app sandbox (EvidencePhotos
  included) — total wipe, OS-level.
- **로컬 데이터 초기화 (Settings → reset)** — `SettingsView.performReset()`:
  fetch-and-`delete` all `Inspection` (cascades items + in-inspection hazards),
  then all remaining `Hazard` (standalone), then all `Site` (cascades areas),
  `modelContext.save()`, then `PhotoStorageService.deleteAllEvidencePhotos()`.
  **Does NOT touch UserDefaults** — see §6.
- **Single-photo delete**: `PhotoStorageService.delete(relativePath:)`; inspection
  delete (`InspectionDetailView.performDelete`) snapshots item+hazard photo paths
  and best-effort deletes the files after the cascade.

---

## 3. Post-launch change classification

Until the app is on the App Store with real user data, the schema may still be
changed freely **provided** you reset the store and re-run the seed/QA flow
(§4 of LAUNCH_CHECKLIST guardrails). **After release**, classify every model
change before merging:

### ✅ Lightweight-safe (SwiftData can infer; no `SchemaMigrationPlan` needed)
- Add a **new optional** field (`T?`) to an existing model.
- Add a new field **with a default value** in the initializer (existing rows get
  the default on read).
- Add a brand-new `@Model` type (and register it in the container list).
- Add a new enum **case** to a String-raw enum (old rows never hold it; new code
  must still handle all cases in `switch`).
- UI-only computed helpers / view code (no stored property change at all).

### ⚠️ Requires an explicit migration (`VersionedSchema` + `SchemaMigrationPlan`, custom stage)
- Add a **non-optional** field **without** a default → old rows can't be decoded.
- **Rename** a property or `@Model` type (SwiftData sees drop+add → data loss
  unless mapped in a migration stage).
- **Delete** a property / model, or change a property's **type**.
- Change a **relationship** (add/remove, change `deleteRule`, change cardinality,
  add an inverse).
- Add `@Attribute(.unique)` to a field that has existing duplicate values.
- Change the **meaning** of `photoPath` (e.g. absolute↔relative, or moving the
  EvidencePhotos folder) — the strings on disk would no longer resolve (§4).

### ⛔ Prohibited (per CLAUDE.md / DOMAIN_TERMS.md)
- **Changing an enum `rawValue` string** (e.g. `notStarted` → `not_started`):
  every persisted row stores the raw string; changing it silently fails to
  decode old rows. Rename the Swift case only with a migration that rewrites
  stored values, and update DOMAIN_TERMS.md first.
- Renaming any domain term without updating DOMAIN_TERMS.md first.
- Changing model fields without explicit approval.

---

## 4. EvidencePhotos ↔ SwiftData consistency rules

Evidence photos are **files**, not SwiftData blobs. `PhotoStorageService` stores
JPEGs under `Documents/EvidencePhotos/<uuid>.jpg` and rows reference them by a
**relative path string** (`ChecklistItem.photoPath: String?`,
`Hazard.photoPath: String` which may be `""`). The store and the folder are two
sources that must stay consistent:

- **Deleting a row** must best-effort delete its photo file (current delete +
  reset paths already do this). A migration that deletes/rewrites rows must do
  the same, or it leaks orphan files.
- **Never** change the path scheme (relative root, folder name `EvidencePhotos`,
  filename = `UUID().uuidString + ".jpg"`) without treating it as a ⚠️ migration:
  existing `photoPath` strings must keep resolving via
  `rootDirectory.appendingPathComponent(relativePath)`.
- Missing files are tolerated by design (`loadDownsampled`/`load` return `nil`),
  so a file lost without its row is a cosmetic gap, not a crash. The dangerous
  direction is a **row whose `photoPath` scheme changed** — handle in migration.
- `Hazard.photoPath` is non-optional; `""` means "no photo". Keep that invariant
  (don't make it optional without a migration + updating every read site).

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

Add this to any PR/task that edits `Models/`:

- [ ] Does this add/rename/delete a stored property, model, or relationship?
- [ ] If yes: is it lightweight-safe (§3 ✅) or does it need a `SchemaMigrationPlan` (§3 ⚠️)?
- [ ] Are all enum `rawValue` strings unchanged? (changing them is ⛔)
- [ ] Are denormalized fields (§1.1) and `photoPath` semantics (§4) preserved?
- [ ] Is `Hazard.inspectionId` still optional and standalone-safe (§5)?
- [ ] Pre-release: did you reset the store + re-run seed/QA? Post-release: is the migration written + tested on a copy of an old store?
- [ ] DOMAIN_TERMS.md updated if any term/enum changed?

When the first post-release change lands, introduce `VersionedSchema`
(`SchemaV1` = the §1 baseline, `SchemaV2` = the change) and a
`SchemaMigrationPlan`, and switch the container to
`.modelContainer(for:migrationPlan:)`.

# PRD.md — SafetyWalk / 현장안전 지킴이

## Priority Legend
- **P0** — Must ship in MVP. Blocking.
- **P1** — Should ship in MVP. High value, not blocking.
- **P2** — Nice to have. Defer if time-constrained.
- **Risk** — Technically or product risky. Handle carefully.

---

## App Structure

### Tab Navigation
| Tab | Label (EN) | Label (KO) |
|---|---|---|
| 1 | Home | 홈 |
| 2 | Inspection | 점검 |
| 3 | Hazards | 위험요인 |
| 4 | History | 기록 |
| 5 | Settings | 설정 |

---

## Feature Specifications

---

### F-01: Home Screen — P0

**Description:** Entry point. Shows the state of the current day at a glance.

**Contents:**
- "Start Inspection" primary button (large, full-width)
- Summary: inspections completed today, open hazards count
- List of recent inspections (last 3–5)
- Quick shortcut to "Add Hazard" outside of an inspection

**Acceptance Criteria:**
- [ ] Home renders without any existing data (empty state)
- [ ] "Start Inspection" navigates to the inspection setup flow
- [ ] Recent inspections list shows site name, date, and pass/fail/hazard count
- [ ] Tapping a recent inspection opens the Inspection Detail screen
- [ ] Empty state shows a friendly prompt, not a blank screen

---

### F-02: Start Inspection Flow — P0

**Description:** Multi-step setup before the checklist walk begins.

**Steps:**
1. Select or create Site
2. Select or enter Area (free text allowed)
3. Select Checklist Template (driven by Region Profile)
4. Begin checklist

**Acceptance Criteria:**
- [ ] User can create a new site with a name (required) and address (optional)
- [ ] User can select an existing site from a saved list
- [ ] Area can be selected from saved areas for that site, or typed as free text
- [ ] Checklist template is pre-selected based on region profile setting
- [ ] User can change template before starting
- [ ] Tapping Back at any step does not lose previously entered values
- [ ] Inspection record is created in local storage when checklist begins

---

### F-03: Checklist Item Marking — P0

**Description:** The core field recording screen. One item at a time or scrolling list.

**Per item fields:**
- Title (from template, localized)
- Category label
- Result: Pass / Fail / N-A (large tap buttons)
- Optional: evidence photo (camera or photo library)
- Optional: short note (text field)

**Behavior:**
- Failed items show a prompt: "Add Hazard?" with quick link
- Items default to unchecked; not submitted until result is set
- Progress indicator shows X of Y items completed

**Acceptance Criteria:**
- [ ] All three result states are tappable with large buttons
- [ ] Photo can be attached inline per item using the camera
- [ ] Note field accepts up to 200 characters
- [ ] Failed item shows "Add Hazard" option; tapping pre-fills hazard with item context
- [ ] Progress bar updates in real time
- [ ] Items can be revisited and changed before inspection is completed
- [ ] Unchecked items are clearly visually distinguished

---

### F-04: Quick Hazard Registration — P0

**Description:** Fast hazard capture, usable both inside and outside an inspection.

**Required fields:**
- Photo (camera, mandatory)
- Location (defaults to current site/area; editable)
- Hazard Type (category picker: Fall / Electrical / Fire / Chemical / General / Other)
- Risk Level (Low / Medium / High buttons — large, color-coded)
- Description (short text, ~200 chars)
- Corrective Action Status (defaults to Not Started; picker)

**UX constraints:**
- Must be completable one-handed
- Camera launches immediately on open
- Location pre-filled from current context
- Corrective action status defaults to Not Started
- Risk level uses color: Low = yellow, Medium = orange, High = red

**Acceptance Criteria:**
- [ ] Photo is required; form cannot be submitted without one
- [ ] Location defaults to current site/area but is editable
- [ ] Hazard type picker shows localized labels
- [ ] Risk level selection uses 3 large color-coded buttons
- [ ] Corrective action status defaults to Not Started
- [ ] Hazard is saved locally on submit
- [ ] Hazard is accessible from both Hazards tab and linked Inspection
- [ ] Form validates required fields before allowing submit

---

### F-05: Inspection Completion & Summary — P0

**Description:** Ends the inspection and shows a summary before sharing.

**Summary shows:**
- Site and area
- Inspector name
- Date/time
- Total items: pass count, fail count, N-A count
- Hazard count by risk level
- List of failed items

**Acceptance Criteria:**
- [ ] Inspector can tap "Complete Inspection" from checklist screen
- [ ] Summary screen shows all counts correctly
- [ ] Inspection status changes to Completed in local storage
- [ ] "Share" button is present (leads to F-09)
- [ ] Completed inspection appears in History tab

---

### F-06: Hazards Tab — P0

**Description:** Full list of all hazards across all inspections.

**Features:**
- List sorted by date (newest first)
- Color-coded risk level indicator per item
- Filter by: Risk Level, Corrective Action Status
- Tap to open Hazard Detail

**Acceptance Criteria:**
- [ ] All hazards display with photo thumbnail, type, risk level, status
- [ ] Filter by risk level works correctly
- [ ] Filter by corrective action status works correctly
- [ ] Tapping a hazard opens detail view
- [ ] Corrective action status can be updated from the detail view

---

### F-07: Inspection History — P0

**Description:** List of all completed and in-progress inspections.

**Acceptance Criteria:**
- [ ] List shows: site name, date, inspector, pass/fail counts
- [ ] Sorted by date (newest first)
- [ ] In-progress inspections are visually distinguished
- [ ] Tapping opens Inspection Detail

---

### F-08: Inspection Detail Screen — P0

**Description:** Full read-only view of a completed or in-progress inspection.

**Shows:**
- Header: site, area, inspector, date, status
- Checklist items grouped by category with result icons
- Evidence photos (tappable for full-size)
- Linked hazards list

**Acceptance Criteria:**
- [ ] All checklist item results are visible
- [ ] Photos are shown as thumbnails, tappable for full view
- [ ] Linked hazards are shown with risk level and status
- [ ] In-progress inspections allow editing (navigate to checklist)

---

### F-09: Share as PDF / Image — P1

**Description:** Generate a shareable inspection summary for KakaoTalk, email, or messages.

**Format:** Simple single-page PDF or rendered UIImage of summary screen.

**Risk:** PDF generation on iOS requires careful handling. Fallback = screenshot share.

**Acceptance Criteria:**
- [ ] Share button on summary screen opens iOS share sheet
- [ ] Output includes: site, inspector, date, item counts, hazard list, photos
- [ ] Share works without internet (local generation only)
- [ ] File size is reasonable (photos compressed, not full resolution)

---

### F-10: Site & Area Management — P1

**Description:** Create, edit, and delete sites and areas from Settings.

**Acceptance Criteria:**
- [ ] User can create a site with name (required) and address (optional)
- [ ] User can add saved areas to a site
- [ ] User can edit or delete sites (with confirmation if inspections reference the site)
- [ ] Deleting a site does not delete historical inspection data (soft link)

---

### F-11: Settings Screen — P1

**Description:** App-level configuration.

**Contents:**
- Inspector name (used in inspection records)
- Language (한국어 / English) — a single toggle that also selects the matching content/region profile (한국어 → Korea, English → Global). The separate Region picker has been folded into this control.
- Site management shortcut
- App version + disclaimer text

**Acceptance Criteria:**
- [ ] Inspector name is saved and pre-populated in all new inspections
- [ ] Language toggle re-renders all app text immediately, without a restart
- [ ] Selecting the language also loads the matching default template on the next inspection (한국어 → Korea, English → Global/U.S.)
- [ ] Disclaimer text is visible and non-removable

---

### F-12: Localization Structure — P0

**Description:** All user-facing strings must be externalized for Korean and English.

**Approach:**
- `.strings` / `.stringsdict` files for system localization
- `LocalizationKey` enum for type-safe string access in SwiftUI
- Checklist template item titles stored as localization keys, not hard-coded strings

**Acceptance Criteria:**
- [ ] No user-facing string is hard-coded in Swift/SwiftUI source
- [ ] Korean and English strings are complete for all P0 screens
- [ ] Switching language shows correct strings for all P0 features
- [ ] Missing translation falls back to English

---

### F-13: Region Profile Structure — P0

**Description:** Korea and Global configuration, affecting checklist templates and terminology. The region profile is **no longer an independent picker** — it is selected implicitly by the F-11 Language toggle (한국어 → Korea, English → Global), so language and content stay consistent.

**Approach:**
- `RegionProfile` model: Korea | Global (unchanged — selected via `LocalizationManager`, persisted via `RegionProfileStore`)
- `ChecklistTemplateLoader` reads JSON files tagged by region
- Terminology loaded from the region's template data

**Acceptance Criteria:**
- [ ] Region profile follows the Language toggle (not a separate control)
- [ ] Korea profile loads the KOSHA-oriented Korean template
- [ ] Global profile offers **two** Federal OSHA-cited templates — General Industry (29 CFR 1910) and Construction (29 CFR 1926), imperial units, user picks explicitly (WO LEGAL-3B; no auto-selection, unlike Korea)
- [ ] Changing language offers the new default template on the next inspection

---

### F-14: Offline-First Local Storage — P0

**Description:** All data persists locally using SwiftData (iOS 17+).

**Models:** Site, Area, Inspection, ChecklistItem, Hazard, Photo (file path reference)

**Acceptance Criteria:**
- [ ] All data survives app termination and relaunch
- [ ] Photos stored as files in app's Documents directory, path saved in model
- [ ] No network call is required for any P0 flow
- [ ] Data model uses UUIDs as primary keys (enables future sync)

---

## Disclaimer Requirement

Every exported summary and the Settings screen must display:

> **EN:** "This app supports field inspection recording and evidence organization. It does not determine legal violations or provide compliance certification. Human safety manager review is required."

> **KO:** "이 앱은 현장 점검 기록 및 증거 정리를 지원합니다. 법적 위반 여부를 판단하거나 법적 준수 여부를 확정하지 않습니다. 안전관리자의 검토가 필요합니다."

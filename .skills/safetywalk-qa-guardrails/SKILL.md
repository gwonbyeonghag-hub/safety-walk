# Skill: SafetyWalk QA Guardrails

Use this skill whenever working on SafetyWalk QA, simulator testing, seed data injection,
build cleanup, or pre-TestFlight verification.

This skill prevents recurring mistakes discovered during MVP QA.

---

## When to Run

- Before injecting SQLite seed data into a running simulator
- Before any simulator UI automation or coordinate-click QA
- After a Xcode build that shows stale file warnings
- Before uninstalling / reinstalling the simulator app
- Before marking any QA task done

---

## 1. SwiftData Enum rawValue Seeding

SafetyWalk models use `String, Codable` enums. The Swift compiler assigns rawValue = case
name by default. **Never insert numeric strings like `"0"`, `"1"`, `"2"` into enum
columns** — SwiftData will throw a DecodingError crash on first read.

| Enum | Valid rawValues |
|---|---|
| `ChecklistItemResult` | `pass`, `fail`, `notApplicable`, `unchecked` |
| `InspectionStatus` | `inProgress`, `completed` |
| `RiskLevel` | `low`, `medium`, `high` |
| `HazardType` | `fallRisk`, `electrical`, `fire`, `chemical`, `general`, `other` |
| `CorrectiveActionStatus` | `notStarted`, `inProgress`, `completed` |

**Wrong:**
```sql
UPDATE ZHAZARD SET ZCORRECTIVEACTIONSTATUS='0';
UPDATE ZHAZARD SET ZRISKLEVEL='2';
UPDATE ZINSPECTION SET ZSTATUS='1';
```

**Correct:**
```sql
UPDATE ZHAZARD SET ZCORRECTIVEACTIONSTATUS='notStarted';
UPDATE ZHAZARD SET ZRISKLEVEL='high';
UPDATE ZINSPECTION SET ZSTATUS='completed';
```

**Crash signature to recognize:**
```
Cannot initialize CorrectiveActionStatus from invalid String value 0
DecodingError.dataCorrupted
```

After any direct SQLite seeding, verify enum columns before launching:
```bash
sqlite3 "$DB" "SELECT ZRESULT FROM ZCHECKLISTITEM;"
sqlite3 "$DB" "SELECT ZSTATUS FROM ZINSPECTION;"
sqlite3 "$DB" "SELECT ZRISKLEVEL,ZTYPE,ZCORRECTIVEACTIONSTATUS FROM ZHAZARD;"
```

---

## 2. Prefer UI or SwiftData Seeding Over Direct SQLite

Direct SQLite is risky because it also requires correctly encoding:
- CoreData reference date (Jan 1 2001, not Unix epoch — subtract 978307200)
- WAL journal state
- relationship foreign keys (ZINSPECTION→ZCHECKLISTITEM, etc.)
- optional vs non-optional column nullability

**Preferred order:**
1. Create QA data through the app UI (safest, always valid)
2. SwiftData ModelContext seed path in debug code if available
3. Direct SQLite only as last resort — always verify enum values and timestamps

---

## 3. Simulator UI Automation Limitations

**Do not over-trust coordinate-based simulator automation.**

Known failure modes:
- `osascript` clicks at `{x, y}` can hit Springboard or a system alert instead of the app
- `simctl launch` returns a PID even when a Watch pairing alert is covering the screen
- Watch pairing / notification permission alerts look like "app didn't open"
- Coordinate mapping is unreliable across simulator scale, device frame, macOS display config

**If the app appears not to open:**
1. Check whether a system alert (Watch, notifications, etc.) is overlaying the screen
2. Check `launchctl list | grep safetywalk` or process status
3. Check `log stream --predicate 'subsystem == "com.safetywalk.app"'`
4. Do not assume a crash until logs confirm it

**After failed automation:** report the ambiguity and ask the user to manually tap the app icon.
Never declare a bug based solely on a failed coordinate click.

---

## 4. Xcode Stale Build Artifact Warnings

Previous CLI builds may have used `SYMROOT=/tmp/safetywalk_build`.
This causes Xcode Issue Navigator warnings:
```
Stale file '/tmp/safetywalk_build/.../SafetyWalk.app/Assets.car' is located outside of the allowed root paths.
```

These are **not source code bugs** — they are leftover build artifact references.

**Fix:**
```bash
rm -rf /tmp/safetywalk_build
rm -rf ~/Library/Developer/Xcode/DerivedData/*SafetyWalk*
rm -rf ~/Library/Developer/Xcode/DerivedData/*현장*
```

Then build without SYMROOT override:
```bash
xcodebuild -project "현장 안전 지킴이.xcodeproj" \
  -scheme "현장 안전 지킴이" \
  -destination "generic/platform=iOS Simulator" \
  -configuration Debug \
  clean build
```

---

## 5. App Reinstall / UserDefaults / Onboarding Behavior

**AppStorage keys SafetyWalk uses:**
```
com.safetywalk.hasCompletedOnboarding
com.safetywalk.inspectorName
com.safetywalk.regionProfile
com.safetywalk.appearanceMode
```

**After `simctl uninstall`:** all AppStorage and SwiftData are wiped. App UUID changes.
Re-run `xcrun simctl get_app_container booted com.safetywalk.app data` to get the new path
before any SQLite work.

**After "Reset Local Data" in Settings:** business data (Inspections, Hazards, Sites, Photos)
is deleted. AppStorage preferences are **preserved**. Onboarding does NOT reappear — this is
by design, not a bug.

**To reopen setup:** Settings → App Setup → Reopen Setup (or set `hasCompletedOnboarding=false`).

---

## 6. SafetyWalk Vocabulary — Do Not Use Login/Auth Terms

SafetyWalk is local-first, offline-only, with no accounts and no server.

| Use | Avoid |
|---|---|
| setup / app setup | login / sign in |
| inspector name | username / account |
| reopen setup | re-authenticate |
| start | sign up |
| region profile | user profile / account settings |

Never add "login", "sign in", "password", or "authentication" vocabulary anywhere in the
app — source, localization, or UI copy.

---

## 7. Read-Only QA Discipline

During QA audits, do not modify source code unless a real blocker is confirmed.

**Before touching any file, determine:**
- Is this an app bug (code defect)?
- Is this a seed data problem (invalid enum values, bad timestamps)?
- Is this a simulator/tooling issue (alert overlay, stale build, wrong container path)?

**Minimal fix only:** propose the specific change, report the root cause, do not apply
broad speculative changes.

**Report format:**
- What was tested (manual vs automated)
- What files changed (list them, or state "no source files changed")
- How data was created (UI, SwiftData, or SQLite)
- Any limitations or items requiring manual verification

---

## 8. Navigation Rule Reminder

Do not add `@Query` with `#Predicate` inside depth-2+ pushed `NavigationLink` destinations.

**Safe pattern:**
```swift
// Root view: owns @Query
@Query var inspections: [Inspection]

// Detail view: receives model, reads relationships
inspection.items.sorted { $0.sortOrder < $1.sortOrder }
inspection.hazards
site.areas.sorted { $0.name < $1.name }
```

Avoid nested `NavigationStack` inside pushed views unless it is a sheet root.

---

## 9. Pre-TestFlight Final QA Checklist

Before declaring MVP / TestFlight-ready, verify:

- [ ] App launches from cold start
- [ ] Launch intro plays once on first install
- [ ] Onboarding gate works (hasCompletedOnboarding=false shows OnboardingView)
- [ ] Reopen Setup shows prefilled name and region, preserves data
- [ ] Home / Inspection / Hazards / History / Settings tabs all render without crash
- [ ] Inspection detail push/pop does not freeze
- [ ] Delete inspection removes record and linked items/hazards
- [ ] Reset Local Data preserves AppStorage preferences
- [ ] Enum-seeded hazards do not cause DecodingError crash
- [ ] Appearance mode (Light/Dark/System) persists across launches
- [ ] PDF/share export renders in light theme regardless of appearance setting
- [ ] `plutil -lint` passes on both `en.lproj/Localizable.strings` and `ko.lproj/Localizable.strings`
- [ ] `PrivacyInfo.xcprivacy` is present
- [ ] No stale build artifact warnings in Xcode Issue Navigator

---

## 10. Simulator Build & Automation Environment (lessons from 2026-06-12)

This machine has friction points that cost a full QA session to rediscover. Check these FIRST.

### 10.1 Use full Xcode, not Command Line Tools
`xcodebuild` fails with "requires Xcode, but active developer directory is CommandLineTools"
if `xcode-select -p` points to `/Library/Developer/CommandLineTools`.

- **CoreSimulator and the asset compiler (actool) read the system `xcode-select` link, NOT the
  `DEVELOPER_DIR` env var.** Setting `DEVELOPER_DIR` is enough for plain `xcodebuild` Swift
  compilation, but simulator-runtime registration and actool will still be broken.
- Fix (requires sudo — ask the user, you cannot run it):
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

### 10.2 Korean target/scheme name is stored NFD — never retype it
The target/scheme `현장 안전 지킴이` is stored decomposed (NFD). A name you type or paste is
usually NFC, so `-scheme "현장 안전 지킴이"` fails with "does not contain a scheme named …"
even though `-list` shows it. **Extract the exact bytes from `-list` and reuse them:**
```bash
SCHEME=$(xcodebuild -project "현장 안전 지킴이.xcodeproj" -list 2>/dev/null \
  | awk '/Schemes:/{getline; gsub(/^[ \t]+/,""); print; exit}')
xcodebuild -project "현장 안전 지킴이.xcodeproj" -scheme "$SCHEME" \
  -destination "id=<booted-sim-udid>" -configuration Debug -derivedDataPath /tmp/sw_dd build
```
There are no `.xcscheme` files on disk; the scheme is auto-generated, so this is the only way.

### 10.3 actool needs a simulator runtime matching the SDK major.minor
If only iOS 26.4 runtime is installed but Xcode ships the iOS 26.5 SDK, the build fails at
`Assets.xcassets: error: No simulator runtime version from [...] available to use with
iphonesimulator SDK version <build>` — Swift compiles fine, only Assets.car fails, so a
partial `.app` (no Assets.car) is produced. Install the matching runtime:
`xcodebuild -downloadPlatform iOS` (~8.5 GB; must run AFTER 10.1, or it won't promote into
`simctl list runtimes`). Verify with `xcrun simctl list runtimes | grep <ver>`.

### 10.4 Destination: pin the booted sim by UDID
`-destination "platform=iOS Simulator,name=iPhone 17 Pro"` can mis-resolve to a physical
device requiring an uninstalled OS. Boot the device and use `-destination "id=<udid>"`.

### 10.5 Driving the UI: what works and what does NOT
There is **no idb, no cliclick, no native `simctl tap`** here. Quartz `CGEventPost` from
python is blocked (no Accessibility permission). The only working synthetic input is
AppleScript System Events, and it has hard limits:

| Target | System Events `click at {x,y}` | Notes |
|---|---|---|
| Tab bar items, buttons, segmented controls, `.bordered`/`.borderedProminent` | ✅ works | |
| ScrollView/VStack custom cards (e.g. Home recent-inspection NavigationLink) | ✅ works | |
| **SwiftUI `List` / `Form` rows (NavigationLink or Button inside)** | ❌ does NOT trigger | category rows, checklist item rows, Settings Form rows |
| `keystroke "..."` into a focused TextField | ✅ works (ASCII; Korean needs IME, avoid) | tap field first, then keystroke in the SAME osascript as `activate` |

Consequence: any flow gated behind a List row (category detail → item mark → **Add Hazard
`.sheet`** → completion → summary → share) cannot be driven by clicks. Verify those by
source review + the 3-CLOSE manual-sim record, or have the user drive them.

### 10.6 Coordinate mapping (when clicks do work)
- Read the Simulator window each click (it can move, and may sit on a **secondary display** at
  x≈3300+; multi-display global coords are fine but the window position drifts).
- AppleScript list-to-text concatenation has no separator — `(position of window 1) as text`
  yields `"3379"&"30"="337930"`. Assign `item 1`/`item 2` to vars first, or regex out integers.
- Device pts → screen: `scaleY=(winH-28)/874`, `ox=winX+(winW-402*scaleY)/2`, `oy=winY+28`,
  then `screen=(ox+devX*scaleY, oy+devY*scaleY)`. Screenshot px ÷ 3 = device pt (402×874 @3x).
- `activate` needs ~0.7–1.0 s before `window 1` is readable, else `-1719 invalid index`.
- **Always verify every click with a fresh `simctl io booted screenshot` and READ it.** Tab
  selection can lag one frame; re-shoot before concluding a click failed.

### 10.7 Reliable, click-free verifications
Prefer these — they need no UI automation:
- Onboarding/appearance/region state: `simctl spawn booted defaults write com.safetywalk.app
  com.safetywalk.hasCompletedOnboarding -bool YES` (+ `inspectorName`, `regionProfile`=KR/GLOBAL,
  `appearanceMode`=system/light/dark), then relaunch and screenshot.
- Reopen-setup prefill, appearance persistence, enum-seed decode safety: seed via defaults /
  SwiftData (valid enum rawValues per §1) then relaunch — no in-app taps required.

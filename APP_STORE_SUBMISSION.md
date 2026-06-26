# APP_STORE_SUBMISSION.md — SafetyWalk / 현장안전 지킴이

App Store Connect submission package — **drafts to review and paste into App Store
Connect**. This is a non-code prep document. Nothing here changes app behavior.

Verified against source/build settings on 2026-06-18. **App facts:**
Bundle ID `com.safetywalk.app` · Display name **SafetyWalk** · Version **1.0** ·
Build **1** · Deployment target **iOS 17.0** · iPhone only · Automatic signing
with a Development Team already configured.

> **Updated 2026-06-25** for shipped changes since the 06-18 verification: an
> **in-app Language toggle (한국어/English)** replaced the standalone region picker;
> the non-Korea checklist is now **US-oriented** (imperial 6 ft/4 ft, SDS, LOTO,
> HazCom, machine guarding, etc.); the launch intro is the **"SafetyWalk" wordmark**
> pen-stroke; EN/KO key parity is now **300=300**. Describe the app as a *language
> switch + Korea/US checklists*, **not** "Korea/Global region profiles."

> **Accuracy guardrails honored below** (do not regress):
> - The app **attaches evidence photos from the photo library** (SwiftUI
>   `PhotosPicker`). It does **not** capture live camera photos in-app — never
>   describe in-app camera capture.
> - **Offline-first / local-only.** No network calls, no cloud sync, no backup,
>   no account. Never imply data leaves the device except the **user-initiated**
>   iOS Share Sheet.
> - **No legal judgment.** Never claim the app determines compliance, violations,
>   or KOSHA/OSHA status. It records inspections; a safety manager reviews.

---

## 1. Metadata draft

**Supported languages: Korean + English — both runtime-verified (2026-06-18).** The
app ships `en.lproj` + `ko.lproj` (full key parity 300=300, plutil OK, all
`LocalizationKey` cases resolve in both); forcing `-AppleLanguages (en)` renders
Home / Hazards / Settings entirely in English (risk High/Medium/Low, status
Not Started/In Progress/Completed, disclaimer, dates), and `(ko)` renders entirely
in Korean. App Store Connect localizations: **Korean (primary, for the Korea store)
+ English**. Listing English is accurate, not aspirational. *Note:* the on-device
app icon name is the brand string **"SafetyWalk"** in both locales (not localized to
"현장안전 지킴이"); the App Store **listing** name can still be localized per store.

Korea is the primary market; the app is bilingual (KO/EN). Provide KO metadata for
the Korean App Store and EN for English locales.

The app now includes an **in-app Language toggle (한국어/English)** in Settings and
Onboarding (this replaced the earlier Korea/Global region picker). The non-Korea
checklist is **US-oriented**. The description should describe a *language switch* and
*Korea / US checklists* — never claim OSHA/KOSHA compliance (no-legal-judgment rule).

### App name (30 chars max)
- KO: **현장안전 지킴이**
- EN: **SafetyWalk – Field Safety**

### Subtitle (30 chars max)
- KO: **현장 점검·위험요인 기록 도구**
- EN: **Jobsite inspections & hazards**

### Promotional text (170 chars, updatable anytime without review)
- KO: 종이 체크리스트 없이 현장에서 바로 점검을 기록하세요. 위험요인·증거 사진·시정 조치 상태를 한곳에서 관리하고, 보고서로 공유합니다. 인터넷 없이도 동작합니다.
- EN: Record safety inspections on-site without paper. Track hazards, evidence photos, and corrective-action status in one place, and share a report. Works fully offline.

### Description (4000 chars max)
- KO:
```
현장안전 지킴이는 건설·제조·시설 현장의 안전 점검을 종이와 엑셀 없이 아이폰에서 바로 기록하는 도구입니다.

■ 주요 기능
· 점검표 기반 현장 점검 기록 (적합 / 부적합 / 해당없음)
· 위험요인 등록 — 유형, 위험 등급(높음·보통·낮음), 위치, 설명, 증거 사진 첨부
· 시정 조치 상태 추적 (미착수 / 진행중 / 완료)
· 점검 기록 조회 및 현장·구역 관리
· 점검 보고서를 PDF로 만들어 메일·메신저로 공유
· 한국어 / 영어 — 설정에서 인앱 언어 전환; 한국·미국 안전 점검표

■ 이렇게 동작합니다
· 인터넷이 없어도 모든 작업이 가능합니다. 데이터는 기기에만 저장됩니다.
· 계정 가입이 필요 없습니다. 앱을 열면 바로 사용할 수 있습니다.
· 증거 사진은 사진 보관함에서 선택해 첨부하며, 기기 안에만 보관됩니다.

■ 안내
이 앱은 현장 점검 기록과 증거 정리를 지원합니다. 법적 위반 여부를 판단하거나
법적 준수 여부를 확정하지 않습니다. 점검 결과는 안전관리자의 검토가 필요합니다.
법령·수치는 응시·적용 시점 기준으로 직접 확인하세요.
```
- EN:
```
SafetyWalk records industrial and construction safety inspections directly on your
iPhone — no paper, no after-the-fact spreadsheet entry.

What you can do
· Record checklist-based inspections (Pass / Fail / N-A)
· Register hazards with type, risk level (High / Medium / Low), location,
  description, and an attached evidence photo
· Track corrective-action status (Not started / In progress / Completed)
· Review past inspections and manage sites and areas
· Export an inspection report as a PDF and share it by email or messaging
· Korean / English with an in-app language switch; Korea and US safety checklists

How it works
· Everything works offline. Your data is stored only on this device.
· No account or sign-in. Open the app and start.
· Evidence photos are chosen from your photo library and kept on-device only.

Note
This app supports recording field inspections and organizing evidence. It does not
determine legal violations or certify regulatory compliance. Inspection results
require review by a qualified safety manager.
```

### Keywords (100 chars, comma-separated, no spaces needed; do not repeat the app name)
- KO: `안전점검,현장점검,위험요인,산업안전,안전관리,점검표,시정조치,건설안전,설비점검,점검일지`
- EN: `safety inspection,jobsite,hazard,EHS,field safety,checklist,corrective action,site audit`

### Category
- **Primary: Business** (industrial safety / field operations tool)
- Secondary: **Productivity**
- (Utilities is an acceptable alternative secondary.)

### Age rating → **4+**
Basis (App Store Connect age-rating questionnaire — all categories answered **None**):
no violence/horror/profanity/sexual/gambling/drug/alcohol content; **no unrestricted
web access**; **no user-generated content shared with other users** (all data is
local to the device); **no third-party advertising**. User-entered text/photos stay
private on-device, which does not raise the rating.

### Copyright
- `© 2026 <법적 권리자 / legal entity name>` *(human fills the entity/owner name)*

### URLs
- **Support URL** — *required by App Store Connect.* Human must provide a reachable
  page (a simple support/contact page or a mailto-style help page). Not yet hosted.
- **Marketing URL** — optional; omit for v1.0 if none.
- **Privacy Policy URL** — *required by App Store Connect.* Host the draft in §2.4
  and paste the URL. Not yet hosted.

---

## 2. App Privacy (App Store Connect "App Privacy" questionnaire)

Grounded in `PrivacyInfo.xcprivacy` + verified source (no `URLSession`/networking,
no analytics/crash/ad SDKs, no `import Photos`/`PHPhotoLibrary`/camera APIs, 0 Swift
Package dependencies).

### 2.1 Tracking
- **Do you track users?** → **No.** No ATT, no `AdSupport`/IDFA, no third-party
  analytics or advertising. `NSPrivacyTracking = false`, `NSPrivacyTrackingDomains`
  empty.

### 2.2 Data collection
- **Do you or your third-party partners collect data from this app?** → **No data
  collected.**
  - Rationale (Apple's definition = data **transmitted off the device**): SafetyWalk
    is offline-first with **no networking of any kind**. Inspector name and region
    preference live in on-device `UserDefaults`; inspections/hazards/areas live in an
    on-device SwiftData store; evidence photos live in the app's sandbox
    (`Documents/EvidencePhotos/`). **None of it is transmitted, synced, or backed up
    by the app.**
  - The **only** outbound path is the **user-initiated iOS Share Sheet** (e.g. Save
    to Files / email a PDF). Apple treats user-initiated sharing via the system share
    sheet as out of scope of "data collection," so this remains **No collection**.
- `NSPrivacyCollectedDataTypes` is intentionally **empty** and is correct.

### 2.3 Required-reason API
- `PrivacyInfo.xcprivacy` declares exactly one: **UserDefaults →
  `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1`** (app reads/writes its
  own defaults). No file-timestamp / disk-space / system-boot-time / active-keyboard
  APIs are used.

### 2.4 Privacy policy draft (host this, then paste the URL)
```
SafetyWalk Privacy Policy

SafetyWalk (현장안전 지킴이) does not collect, transmit, or share any personal data.

· The app works entirely offline. It makes no network connections.
· Inspection records, hazards, areas, and the inspector name you enter are stored
  only on your device.
· Evidence photos are selected by you from your photo library and stored only in
  the app's private storage on your device.
· The app uses no analytics, advertising, or tracking technologies, and contains no
  third-party SDKs.
· Data leaves your device only when you explicitly choose to share a report through
  iOS (for example, email or Save to Files). That action, and where the file goes,
  is entirely under your control.
· Deleting the app, or using Settings → Reset local data, removes this on-device
  data.

This app does not determine legal violations or certify regulatory compliance.

Contact: <support email / page>
Last updated: <date>
```
*(Human: replace contact + date, host at a public URL.)*

---

## 3. Screenshots

### Captured candidates (this package)
Folder: `docs/app-store-screenshots/` — **iPhone 16 Plus, light mode, 1290×2796
(6.7"), natural Korean seed data:**

| File | Screen | Why |
|---|---|---|
| `01-home-risk-rail.png` | Home — open-hazard risk rail + recent inspections | Signature glance: counts by risk level + quick start |
| `02-inspections.png` | Inspection tab — active inspection + 점검 시작 CTA | Core action |
| `03-hazards-list.png` | Hazards list — High/Medium/Low + status badges | Risk-color language (red/orange/gold) |
| `04-history.png` | History — completed + in-progress records | Review on-device |
| `05-settings.png` | Settings — appearance, site mgmt, local reset, disclaimer | Local-data control + disclaimer |

### Apple size requirements (human action)
- App Store Connect currently requires **6.9-inch (1320×2868, iPhone 16 Pro Max)**
  and **6.5-inch (1242×2688)** screenshots; **6.7-inch (1290×2796)** is widely
  accepted/scaled. The captures above are **6.7"** — re-capture on a **6.9" / 6.5"**
  simulator if App Store Connect rejects the size, using the same screens + seed.
- iPad screenshots are **not** required (iPhone-only app).

### Recommended additional shots (not auto-capturable — navigation/share are gated
by toolbar/list/sheet synthetic-click limits; capture in a quick manual run):
- **Checklist screen** (점검 진행 — Pass/Fail/N-A buttons, photo attach, note)
- **Hazard detail** (위험요인 상세 — corrective-status picker)
- **Shared PDF report** (open the exported report in Files / Quick Look — the report
  design is already runtime-verified in the P1 Share/Export item)

---

## 4. Reviewer notes (App Review "Notes" field) — draft

```
SafetyWalk is an offline-first field safety inspection tool for iPhone.

· No account or login is required — open the app and use it immediately.
· No network connection is needed or used; all data is stored on-device.
· To exercise the main flow: Settings → 현장 관리 (Site management) → add a site →
  Home → 점검 시작 (Start inspection) → choose the site → mark checklist items
  (Pass / Fail / N-A) → on a Fail item or the Hazards tab, register a hazard and
  attach a photo from the photo library → complete the inspection → Share to export
  a PDF report.
· Evidence photos are attached via the system Photos picker (PHPicker); the app
  never accesses the photo library directly and shows no library permission prompt.
· The app does not determine legal violations or certify compliance; it records
  inspections for review by a safety manager. A disclaimer to this effect appears
  on the report and in Settings.

Demo account: not applicable (no accounts).
```

---

## 5. Final pre-submit checklist

Code/build (verified this pass):
- [x] Bundle ID `com.safetywalk.app`; Version 1.0; Build 1 *(bump build for each upload)*
- [x] Deployment target iOS 17.0; iPhone-only orientations set
- [x] `PrivacyInfo.xcprivacy` present + bundled in the built `.app` (UserDefaults/CA92.1 only)
- [x] App icon: single 1024×1024, no alpha, in `AppIcon` asset; compiled into `Assets.car`
- [x] Launch screen: adaptive `LaunchBackground` color via Info.plist `UILaunchScreen` (light=white / dark=black); `UILaunchScreen_Generation = NO` (2026-06-23 dark-launch fix)
- [x] Usage strings: `NSPhotoLibraryUsageDescription` present; `NSCameraUsageDescription` removed (camera unused)
- [x] No networking / tracking / analytics / crash SDK / 3rd-party packages (rg-verified)
- [x] `xcodebuild build` SUCCEEDED (Debug, simulator)

Human steps in Xcode / App Store Connect (cannot be done from here):
- [ ] **Archive** in Xcode (Any iOS Device) with Distribution signing → validate → upload (Automatic signing + Development Team already configured)
- [ ] (Optional) TestFlight internal test of the uploaded build before release
- [ ] Create the App Store Connect record; paste **§1 metadata** (KO + EN) and **§2 privacy** answers
- [ ] Host **§2.4 privacy policy** + a **support page**; paste both URLs
- [ ] Upload **§3 screenshots** at the required size(s); add the recommended extra shots from a manual run
- [ ] Set **Category = Business** (secondary Productivity), **Age rating = 4+**, **Copyright** owner
- [ ] Paste **§4 reviewer notes**
- [ ] Confirm export-compliance answer (no non-exempt encryption — app uses no custom crypto/networking)

---

## 6. Known limitations / risks to disclose internally (not for the store listing)
- Evidence photos attach from the **library only** (no in-app camera) — keep metadata
  consistent with this.
- PDF report is a **single tall A4-width page** (no multi-page pagination yet) — fine
  for email/messaging; tracked as a P2 follow-up.
- Screenshots captured at **6.7"**; App Store may require 6.9"/6.5" — re-capture if so.
- Light/dark both supported; screenshots use light. (A simulator prefs-cache quirk made
  in-place light toggling unreliable; resolved by a fresh install — not an app issue.)

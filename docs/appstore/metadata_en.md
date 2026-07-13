# App Store metadata (English) — SafetyWalk / 현장안전 지킴이

Draft to paste into App Store Connect (English localization). No code/behavior change.
v2 scope (risk assessment 4 methods · iCloud sync · iOS+iPad+macOS · SafetyWalk Pro
subscription) — verified against source 2026-07-10.

> **Accuracy guardrails (do not regress)**
> - **No legal judgment**: never claim it determines violations or certifies compliance.
> - **iCloud sync**: v2 syncs to the user's **own private iCloud (CloudKit private DB)**.
>   Do NOT say "fully offline / no network." It *works* offline, but it syncs via iCloud.
> - **Photos** are **attached from the library** (no in-app camera capture).
> - **Subscription**: SafetyWalk Pro is auto-renewable; free core (inspections/hazards)
>   stays free; **price is whatever the App Store shows** (never hard-code).

## App name (30 chars max)
- **SafetyWalk – Field Safety**

## Subtitle (30 chars max)
- **Inspections & risk assessment**

## Promotional text (170 chars, editable anytime)
- Record jobsite inspections, hazards, and risk assessments (4 methods) on-site — no paper. Syncs across iPhone, iPad, and Mac via your own iCloud; share results as PDF.

## Description (4000 chars max)
```
SafetyWalk records industrial and construction safety inspections and risk
assessments directly on iPhone, iPad, and Mac — no paper, no after-the-fact
spreadsheet entry.

What you can do
· Record checklist-based inspections (Pass / Fail / N-A)
· Register hazards with type, risk level (High / Medium / Low), location,
  description, and an attached evidence photo
· Track corrective-action status (Not started / In progress / Completed)
· Run risk assessments with 4 methods — 3-Level (High/Med/Low), Frequency ×
  Severity (1–9 score with a matrix), Checklist, and JSA/JHA (step-by-step
  job hazard analysis)
· Export inspection and assessment reports as a PDF and share them
· macOS manager dashboard — see hazards, open corrective actions, and assessment
  due dates across sites at a glance, and print/export reports
· Korean / English with an in-app language switch; Korea and US safety checklists

How it works
· You can record on-site without internet (offline-first).
· Your records are stored on the device and synced securely to your own private
  iCloud, so you can continue on iPhone, iPad, and Mac. The developer has no access
  to this data.
· No account or sign-in. Open the app and start.
· Evidence photos are chosen from your photo library and kept in the app's storage.

SafetyWalk Pro (optional subscription)
· Always free: inspection checklists, hazard registration/management, record
  viewing, site/area management, iCloud sync, and settings.
· Pro unlocks: creating risk assessments (all 4 methods) and exporting inspection
  reports as PDF.
· If your subscription ends, risk assessments you already created stay viewable.
· Monthly and yearly auto-renewable subscriptions. Price is shown in the App Store.

Note
This app supports recording field inspections and risk assessments and organizing
evidence. It does not determine legal violations or certify regulatory compliance.
Results require review by a qualified safety manager.
```

## Keywords (100 chars, comma-separated, do not repeat the app name)
```
safety inspection,risk assessment,JSA,jobsite,hazard,EHS,field safety,corrective action,site audit
```

## Category
- **Primary: Business** · Secondary: **Productivity**

## Age rating → **4+**
No violence/horror/profanity/sexual/gambling/drug content; no unrestricted web access;
no user-generated content shared with other users (data is in the user's private
iCloud); no third-party advertising.

## Copyright
- `© 2026 <legal entity / owner name>` *(owner fills)*

## URLs
- **Support URL** (required): host `docs/support.md`, paste the URL.
- **Privacy Policy URL** (required): host `docs/appstore/privacy_policy.md`, paste the URL.
- **Marketing URL** (optional): omit for v1.0 if none.

## App facts
- iOS bundle `com.gwonbyeonghag.safetywalk` · macOS bundle `com.gwonbyeonghag.safetywalk.mac`
- Version **1.0** · build **1** · iOS **17.0**+ / macOS **14.0**+ · iPhone, iPad, Mac
- iCloud container `iCloud.com.gwonbyeonghag.safetywalk` (private CloudKit)
- Subscription group **SafetyWalk Pro** · products `...pro.monthly` / `...pro.yearly`
  (owner registers + prices in Connect)

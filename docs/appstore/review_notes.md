# App Review Notes — SafetyWalk v2

App Store Connect "App Review Information → Notes" 필드에 붙여넣을 초안. 두 앱(iOS·macOS) 공통.

---

## English (paste this)

```
SafetyWalk is an offline-first field safety inspection and risk-assessment tool for
iPhone, iPad, and Mac.

No account / login
· No account or sign-in is required. Open the app and use it immediately.
· iCloud is optional. The app works fully offline; if the device is signed in to
  iCloud, records sync to the user's own private iCloud (CloudKit private database),
  which the developer cannot access. No sign-in is needed to review the app.

How to exercise the main flow
1. Onboarding: enter an inspector name, choose language (Korean/English), Start.
2. Settings → Site management → add a site.
3. Home → Start inspection → pick the site → mark checklist items (Pass / Fail / N-A).
4. On a Fail item or the Hazards tab, register a hazard and attach a photo from the
   photo library (system Photos picker; the app never accesses the library directly).
5. Complete the inspection → Share to export a PDF report.

In-App Purchase (SafetyWalk Pro — auto-renewable subscription)
· Free (no purchase): inspections, hazards, record viewing, site management, iCloud
  sync, settings — the full field workflow.
· Pro unlocks two things: creating a new Risk Assessment (Home → 위험성평가 / Risk
  Assessment → + ) and exporting an inspection report as PDF (Share button). Tapping
  either as a non-subscriber presents the paywall (Settings → SafetyWalk Pro also
  offers Subscribe / Restore Purchases).
· Please test the subscription in the sandbox: open the paywall, purchase Monthly or
  Yearly, then the gated actions open. "Restore Purchases" re-checks entitlements.
· Important: if a subscription lapses, risk assessments the user already created remain
  viewable (only new creation and PDF export are gated) — records are never held hostage.

No legal judgment
· The app records inspections and risk assessments for review by a safety manager. It
  does not determine legal violations or certify regulatory compliance. A disclaimer to
  this effect appears in Settings, on the Risk Assessment detail, and on every exported
  report/PDF.

Demo account: not applicable (no accounts).
```

## 한국어 (참고 · 필요 시 병기)

```
현장안전 지킴이는 iPhone·iPad·Mac용 오프라인 우선 현장 점검·위험성평가 기록 도구입니다.

계정 없음
· 로그인·회원가입이 필요 없습니다. 앱을 열면 바로 사용합니다.
· iCloud는 선택입니다. 앱은 오프라인으로 완전히 동작하며, iCloud에 로그인돼 있으면 사용자
  본인의 비공개 iCloud(CloudKit)로 동기화됩니다(개발자는 접근 불가). 심사에 로그인 불필요.

주요 플로우
1. 온보딩: 점검자 이름·언어 입력 → 시작.
2. 설정 → 현장 관리 → 현장 추가.
3. 홈 → 점검 시작 → 현장 선택 → 점검 항목(적합/부적합/해당없음) 기록.
4. 부적합 항목 또는 위험요인 탭에서 위험요인 등록 + 사진 첨부(시스템 사진 선택기).
5. 점검 완료 → 공유로 PDF 보고서 내보내기.

인앱 구입(SafetyWalk Pro — 자동 갱신 구독)
· 무료: 점검·위험요인·기록 조회·현장 관리·iCloud 동기화·설정(현장 워크플로 전체).
· Pro 해제: 위험성평가 신규 작성, 점검 리포트 PDF 내보내기. 비구독 상태로 진입 시 페이월 표시
  (설정 → SafetyWalk Pro에서 구독/복원 가능). 샌드박스에서 월간/연간 구매·복원 테스트 가능.
· 구독이 끝나도 이미 작성한 위험성평가는 계속 조회됩니다(신규 작성·PDF 내보내기만 잠금).

판정 아님
· 법적 위반·준수를 판단·인증하지 않습니다. 면책 고지가 설정·위험성평가 상세·모든 보고서에 표시됩니다.
```

# 스크린샷 계획 — SafetyWalk v2

App Store Connect 업로드용 스크린샷 상태·계획. 실기록 화면만 사용(과장·합성 금지).

## 이미 확보된 자산
### `docs/appstore/screenshots/` (v2, 이번 WO)
| 파일 | 화면 | 크기(현재) |
|---|---|---|
| `macos-01-dashboard.png` | macOS 관리 대시보드(시드 데이터: 현장·위험·미조치·평가기한) | 1040×732 창캡처 |
| `ios-paywall-ko-light.png` / `-ko-dark.png` / `-en-light.png` | SafetyWalk Pro 페이월(월간/연간·실 StoreKit 가) | iPhone 16 (1179×2556) |
| `ios-risk-assessment-create.png` | 위험성평가 신규 작성(빈도×강도) | iPhone 16 |

### `docs/app-store-screenshots/` (v1, 재사용 가능 — 6.7" 1290×2796, ko 라이트)
`01-home-risk-rail` · `02-inspections` · `03-hazards-list` · `04-history` · `05-settings`
— 홈/점검/위험요인/기록/설정 화면은 v2에서도 동일 구조라 그대로 쓸 수 있음(단, 아래 크기 참고).

## Apple 크기 요건 (오너 재캡처 기준)
- **iPhone 6.9"** = **1320×2868** (iPhone 16 Pro Max 시뮬) — Connect 권장. 6.7"(1290×2796)는 대개 허용.
- **iPad 13"** = **2064×2752** (iPad Pro 13 시뮬).
- **macOS** = 1280×800 / 1440×900 / 2560×1600 / **2880×1800** 중. 위 창캡처는 내용 참고용 — Retina에서
  창을 해당 크기로 키워 재캡처.

## 남은 캡처(권장 · 자동화 자산 있음)
헤드리스 자동입력·사진 첨부 한계로 "완전 populated 점검/위험요인(+사진)" 세트는 짧은 수동/캡처 패스가
가장 빠름. 다만 아래는 **기존 UI 테스트로 재현**되므로 시뮬만 6.9"/iPad로 바꿔 재실행하면 됨:
- **위험성평가 4기법·상세**: `현장 안전 지킴이UITests/WO5ScreensUITests.swift`(라/다 + RA 생성/상세 캡처) ·
  `RiskMethodsUITests`(JSA·체크리스트법). `-com.safetywalk.uitestPro 1`로 Pro 상태.
- **페이월(라/다·ko/en)**: `ProPaywallUITests.testPaywallForNonSubscriber`(4콤보 캡처, `.xcresult` 첨부).
- 캡처 추출: `xcrun xcresulttool export attachments --path <result> --output-path <dir>`.

### 수동 캡처 권장(자동화 어려움 — 사진 첨부·PHPicker §10)
- iOS **홈(데이터 채운)** · **점검 진행(적합/부적합/사진/비고)** · **위험요인 상세(시정상태)** · **PDF 리포트 미리보기**.
- iPad **split view 홈** · **위험성평가**.
- 각 ko 우선, 여력 시 en, 다크 1~2장 혼합.

## 캡처 방법 메모
- iOS 시뮬: `xcrun simctl io <udid> screenshot out.png` (앱 실행 중). 언어=런치인자 `-com.safetywalk.appLanguage ko|en`,
  외형=`-com.safetywalk.appearanceMode light|dark`, 온보딩 건너뛰기=`-com.safetywalk.hasCompletedOnboarding 1`.
- macOS: 창만 캡처(`screencapture -l <windowID>`), 데스크톱·타 앱 포함 금지.

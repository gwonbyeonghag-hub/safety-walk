# 스크린샷 계획 — SafetyWalk v2

App Store Connect 업로드용 스크린샷. 실기록 화면만 사용(과장·합성 금지). 소스 검증 2026-07-10(캡처 패스).

## 확보된 자산 — `docs/appstore/screenshots/` (규격 그대로, 업로드 가능)

### iPhone 6.9" — 1320×2868 (iPhone 16 Pro Max 시뮬)
| 파일 | 화면 |
|---|---|
| `iphone-01-home-ko-light.png` / `-ko-dark.png` | 홈(populated: 현장 3·미조치 위험 5·평가기한 1·최근 점검) |
| `iphone-02-checklist-ko-light.png` | 체크리스트 진행(적합/부적합·사진·위험요인 연결됨) |
| `iphone-03-hazard-ko-light.png` | 위험요인 목록(사진·높음 리스크 칩·미착수) |
| `iphone-04-risk-assessment-ko-light.png` | 위험성평가 신규 작성(빈도×강도 입력) |
| `iphone-05-report-ko-light.png` | 점검 완료 리포트(적합/부적합·위험등급별·부적합 항목) |
| `iphone-06-paywall-ko-light.png` / `-ko-dark.png` | SafetyWalk Pro 페이월(실 StoreKit 월간/연간가) |

### iPad 13" — 2064×2752 (iPad Pro 13 시뮬)
| 파일 | 화면 |
|---|---|
| `ipad-01-home-ko-light.png` | split view 홈(사이드바 펼침 + 진행중 점검) |
| `ipad-02-risk-assessment-ko-light.png` | split view 새 위험성평가 작성 시트 (WO-12 수정 후) |

이전 버전에서 이 화면이 "미확보"였던 이유는 실제 앱 버그였음 — WO-12에서 규명·수정 완료
(`.navigationSplitViewStyle(.balanced)` + `columnVisibility = .all`). 자세한 내용은
`V2_HANDOFF.md` §WO-12 참고.

### macOS — 2880×1800
| 파일 | 화면 |
|---|---|
| `macos-01-dashboard-ko-light.png` / `-ko-dark.png` | 관리 대시보드(WO-11 균일 카드 — 시드 데이터) |
| `macos-02-reports-ko-light.png` / `-ko-dark.png` | 리포트 허브(사이드바 + PDF 미리보기, 위험성평가표) |

## WO-13 검증 스샷 (제출용 아님) — `docs/appstore/screenshots/verification/`

기록 탭 그룹핑 + SafetyWalk 내부 이름 병기(WO-13)의 검증 증거. **제출 세트가 아니라 검증용**이라
별도 하위폴더에 둔다(위 제출 카탈로그와 구분). 규격 크기(iPhone 1320×2868 · iPad 2064×2752), ko, 라/다.
- `wo13-iphone-history-bydate-ko-{light,dark}.png` — 날짜순(오늘/어제/이번 주/이번 달/그이전 "YYYY년 M월")
- `wo13-iphone-history-bysite-ko-{light,dark}.png` — 현장순(현장명 오름차순, 그룹 내 최신순)
- `wo13-iphone-onboarding-ko-{light,dark}.png` — 온보딩 타이틀 "SafetyWalk" + 국문 병기 "현장 안전 지킴이"
- `wo13-ipad-history-bydate-ko-{light,dark}.png` / `wo13-ipad-history-bysite-ko-{light,dark}.png` — iPad split view(사이드바 헤더 "SafetyWalk" 포함)

재현: `현장 안전 지킴이UITests/HistoryScreenshots{,IPad}UITests.swift` — DEBUG 런치인자
`-com.safetywalk.uitestSeedHistory 1`로 인메모리 백데이트 시드(실 저장소/CloudKit 무접촉, Release 스트립됨)를 켜고
캡처, `xcrun xcresulttool export attachments`로 추출. 좌표 클릭 없음(탭바/사이드바/세그먼트 접근성 라벨만).

## Apple 크기 요건 (참고)
- **iPhone 6.9"** = 1320×2868 — Connect 권장. 6.7"(1290×2796)는 대개 허용.
- **iPad 13"** = 2064×2752.
- **macOS** = 1280×800 / 1440×900 / 2560×1600 / **2880×1800** 중.

## 캡처 방법 (재현용)
- **iOS/iPad**: XCUITest(`현장 안전 지킴이UITests/AppStoreScreenshotsUITests.swift`,
  `AppStoreScreenshotsIPadUITests.swift`) — 실제 UI 플로우로 사이트·점검·위험요인·위험성평가를
  생성하며 `app.screenshot()`으로 첨부, `xcrun xcresulttool export attachments`로 추출.
  시뮬레이터 스크린샷은 기기 네이티브 해상도와 정확히 일치(리샘플 불필요). 사진 첨부는
  `xcrun simctl addmedia <udid> <jpg>`로 라이브러리를 미리 채운 뒤 PHPicker를
  `app.images.matching(identifier: 'PXGGridLayout-Info')`로 접근해 자동화(좌표 클릭 없음).
- **macOS 대시보드**: `SafetyWalkMac/MacScreenshotEvidence.swift`(DEBUG 전용) —
  `defaults write com.gwonbyeonghag.safetywalk.mac mac.debug.dumpScreenshots -bool true` 후 실행하면
  오프스크린 `NSWindow`+`NSHostingView`+`cacheDisplay`로 1440×900pt/2x를 앱 샌드박스 컨테이너
  (`FileManager.default.temporaryDirectory`)에 렌더링 후 종료. `ImageRenderer`는 이 화면(ScrollView+
  LazyVGrid)에서 재현적으로 빈 화면을 반환해 사용하지 않음.
- **macOS 리포트 허브**: 위 방식은 PDFKit 미리보기(레이어 기반 뷰)가 `cacheDisplay`에 잡히지 않아
  실제 창 캡처로 전환 — 실행 중 앱에서 Accessibility `select`(좌표 클릭 아님)로 사이드바 "리포트"
  행 선택 → 창을 1440×900pt로 정확히 리사이즈 → `screencapture -l <windowID>` → `sips -z 1800 2880`로
  정확히 2배 업스케일(1440×900 정수배라 화질 손실 없음).

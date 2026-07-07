# SafetyWalk 출시 전 디자인 점검 (채점 비평)

**일자**: 2026-07-07 · **범위**: 리뷰만 (코드 수정 0) · **대상**: iOS(iPhone·iPad) + macOS 동시출시 빌드
**루브릭**: ui-craft 채점 비평(Nielsen 10 + 고전 6법칙 + anti-slop 게이트) + Apple HIG + 안전 도메인 페르소나 + `DESIGN_DIRECTION.md` 일치
**태그**: `blocks-launch`(출시 블로커) / `reduces-trust`(신뢰 저하) / `adds-friction`(마찰) / `minor-polish`(경미)

---

## 0. 방법론 · 커버리지 · 증거

| 표면 | 라이트 | 다크 | 증거 |
|---|---|---|---|
| iPhone 홈 | ✅ | ✅ | 시뮬 스샷 (WO-7) |
| iPhone 온보딩 (첫 실행) | ⚠️ | — | **UI 미표시** (아래 F-1) |
| iPhone 앱 아이콘 | ✅ | ✅ | 스프링보드 스샷 |
| iPad (regular) 홈 split view | ✅ | ✅ | 시뮬 스샷 (WO-7) |
| macOS 대시보드·브라우즈·리포트 | ✅ | ✅ | 시뮬 스샷 (WO-8, 시드 populated) |
| iOS 점검·위험요인·위험성평가(4기법)·설정·리포트 | 코드 | 코드 | SwiftUI View 정독 |

- **populated 데이터**: macOS는 DEBUG 시드로 실데이터 캡처됨(현장 3·점검·위험요인·위험성평가 4기법 리포트 모두). iOS는 DEBUG 시드가 없고 첫 실행 온보딩이 표시되지 않아(F-1) UI 자동 캡처가 막혀, **점검 실행·위험요인 등록·위험성평가 입력(4기법)·리포트 iOS 표면은 SwiftUI 소스 정독으로 채점**했다. macOS 리포트 허브 스샷이 4기법 산출물(위험성평가표·JHA)의 시각 근거를 보완한다.
- **접근성**: VoiceOver·Dynamic Type 슬라이더·대비는 Accessibility Inspector(GUI) 헤드리스 실행 불가라 **코드 감사 + 육안**으로 보고, 실측 필요 항목은 부록 B에 `확인 필요(수동)`로 남김.
- 스크린샷은 전부 본인 앱 시뮬레이터 창.

**전체 판정 (한 줄): 🟡 "이것만 고치고 출시" — 단, F-1(첫 실행 UI 미표시)을 실기기에서 먼저 재현/해소해야 하며, 재현되면 판정은 즉시 🔴 재작업으로 내려간다.**

---

## 1. 우선순위 Punch List

### 🔴 blocks-launch (출시 전 필수 — 1건, 검증 선행)

**F-1 — 첫 실행(온보딩) UI가 표시되지 않음 (clean install)**
`reduces-trust`가 아니라 잠재 `blocks-launch`. **모든 신규 사용자가 처음 보는 화면**이라 재현되면 아무도 온보딩을 통과 못 한다.
- **증거**: 완전 초기화(`simctl erase`)한 iPhone 16 시뮬에 fresh install → 실행 시 프로세스는 뜨나(PID 할당) **온보딩 화면이 5초·18초 후에도 안 나오고 스프링보드만** 보임. **크래시 리포트 없음**, 콘솔엔 무해한 `CoreData: NSManagedObjectModel version checksum while the model is still editable`만. 반면 `hasCompletedOnboarding=true`(온보딩 이후) 경로는 정상 렌더(홈 스샷 존재).
- **유력 원인 가설**: `SafetyWalkApp.swift`의 `static let modelContainer = try ModelContainer(..., cloudKitDatabase: .private("iCloud.com.gwonbyeonghag.safetywalk"))` 가 **iCloud 계정 미로그인 환경의 첫 실행(기존 store 없음)** 에서 초기화가 지연/실패 → 씬 표시 지연 또는 조용한 종료. 온보딩 이후 경로가 멀쩡한 건 이전 실행에서 store가 이미 생성돼 있어서일 가능성.
- **해야 할 것 (수정 아님, 검증)**: **iCloud 로그인된 실기기에서 clean install 첫 실행 스모크 테스트**. (a) 정상 표시되면 시뮬 특유 아티팩트 → F-1 강등(minor, 문서화만). (b) 재현되면 `ModelContainer` 생성 실패 시 **로컬 스토어 폴백**(`cloudKitDatabase: .none` 또는 in-memory 재시도)으로 첫 실행이 절대 막히지 않도록 — 오프라인 완결성 원칙(CLAUDE.md)과도 정합.
- 관련 파일: `현장 안전 지킴이/현장 안전 지킴이App(SafetyWalkApp).swift`(static container + `fatalError`), `ContentView.swift`(온보딩 게이트).
- 루브릭: Nielsen #9(오류 복구)·#5(오류 예방); Tesler(복잡성을 사용자에게 떠넘김 — 계정 없으면 못 씀).

### 🟠 reduces-trust (신뢰 저하 — 우선)

**F-2 — iPad 홈 "위험성평가 기한" 카드 빈 상태 문구 오표기**
`reduces-trust` · `minor-polish`. WO-7에서 `assessmentsDueCard`의 빈 상태가 `LocalizationKey.homeNoOpenHazards`("미처리 위험요인 없음")를 재사용 — **평가 기한 카드인데 "위험요인 없음"이라 표시**. 사용자가 데이터 정합성을 의심하게 됨.
- 수정: 전용 문구 신설(예: `home.assessmentsDue.empty` = "기한 도래 평가 없음 / No assessments due"), EN/KO 패리티.
- 파일: `Views/Home/HomeView.swift` `assessmentsDueCard`.
- 루브릭: Nielsen #2(시스템-현실 일치); anti-slop("디자이너가 다시 손볼까? → 예").

**F-3 — 앱 아이콘이 시대에 뒤진 스큐어모픽 느낌**
`reduces-trust`(전문 안전 도구 인상 약화) · `minor-polish`. 광택 베벨 3D 방패 + 어두운 텍스처 배경 = 2010년대 초 미감. iOS 현행 아이콘(플랫+미묘한 깊이)과 이질. 오렌지 체크는 브랜드 마크로 OK(DESIGN_DIRECTION)지만 **실행(광택·잡텍스처)** 을 정돈 권장.
- 수정: 아이콘 리디자인(플랫 방패 + 절제된 depth, navy 기반, 오렌지 체크 유지). 출시 필수는 아니나 첫인상·스토어 썸네일 영향 큼.
- 루브릭: anti-slop 게이트; DESIGN_DIRECTION(절제·시그니처).

### 🟡 adds-friction (마찰 — 장갑·급함 페르소나 가중)

**F-4 — 위험성평가 빈도×강도 입력이 segmented control(1–3), 탭타깃 <44pt**
`adds-friction`. `RiskAssessmentItemEditorView.freqSeverityInput`의 가능성·중대성 선택이 iOS segmented(높이 ~32pt). 현장 페르소나(장갑·야외)에는 작다(Fitts). 같은 화면의 3단계 상/중/하 버튼은 44pt로 잘 돼 있어 대비됨.
- 수정: freq×severity도 3단계 버튼과 동일한 큰 탭타깃(≥44pt) 세그먼트/버튼으로 통일.
- 동일 이슈(경미): 설정·온보딩의 언어/외형 segmented(~32pt) — 저빈도라 우선순위 낮음.
- 루브릭: Fitts; HIG 44pt; 도메인 가중(C).

**F-5 — 고정 폰트 크기가 Dynamic Type 미추종**
`adds-friction` · `minor-polish`. WO-7/WO-8에서 도입한 `.font(.system(size: 13.5/12/29 …))` 고정 크기(iPad 카드·macOS 토큰·DetailField 등)는 **Dynamic Type로 안 커짐** → 저시력·큰글자 사용자 접근성 저하. iOS 본문 다수는 `.subheadline` 등 시맨틱이라 OK.
- 수정: iOS(iPad 홈 카드·DuePill 등) 사용자 대면 텍스트는 `.font(.subheadline)`/`.body` 시맨틱 또는 `@ScaledMetric`로. macOS는 우선순위 낮음(Dynamic Type 비중 작음).
- 루브릭: HIG Dynamic Type; Nielsen #7(유연성).

### ⚪ minor-polish

- **F-6** macOS 대시보드/브라우즈: 창 타이틀바 섹션명 + 콘텐츠 h1 중복(WO-8에서 인지). `minor-polish`.
- **F-7** 위험요인 등록(`HazardRegistrationView`): 사진이 **저장 필수 조건**(`canSave`에 이미지). 증거 사진 요구는 도메인상 합리지만, 사진 없이 급히 기록하려는 현장 상황에선 마찰 가능 — 도메인 의사결정 사안으로 남김(결함 아님). `adds-friction`(약).
- **F-8** 온보딩: 이름을 왜 받는지(리포트에 표기됨) 한 줄 설명 없음 → "왜 이름을?" 주저. `minor-polish`.

---

## 2. 화면별 발견 (요약)

- **온보딩** (코드): 방패+타이틀+이름+언어 세그먼트+면책+시작(이름 없으면 disabled). 깔끔. **단 F-1로 실제 표시 미확인**. 면책 고지 포함 = 신뢰(+). → F-1, F-8.
- **iPhone 홈** (스샷): dense-but-calm. 미조치 위험 rail·점검요약·점검시작(navy primary, 큰 타깃)·위험성평가 진입·최근점검. Hick(액션 소수)·Fitts(주 버튼 큼) 양호. 대시보드 아님 = DESIGN_DIRECTION 준수. 이슈 없음(강점).
- **iPad 홈 split view** (스샷): 사이드바(앱 아이덴티티+6섹션, navy 선택)+2단 홈. 네이티브·정돈. → F-2(빈 문구), F-5(고정폰트).
- **점검 실행** (`ChecklistView`, 코드): pass/fail/NA 44pt 풀폭 3분할(green/red/gray), 사진·비고·fail 시 위험요인 연계. 현장 핵심 플로우가 큰 타깃·명확 상태로 잘 설계(Fitts·오류예방 강점). 이슈 없음.
- **위험요인 등록** (코드): 사진 필수→F-7. 위험등급 버튼 48pt·위험색(의미). 표준 폼. 양호.
- **위험성평가 입력 4기법** (코드): 방법 메뉴 피커(Hick 적합). 3단계=상/중/하 44pt 버튼(위험색=의미). 빈도×강도=세그먼트(1–3)+**라이브 점수·RiskChip**(Doherty 즉시 피드백, 앱 차별점의 핵심 강점). → F-4(세그먼트 타깃).
- **위험성평가 상세** (코드): 읽기전용, 면책, RiskChip, 빈도×강도 분해, JSA 스텝번호. 정돈. 이슈 없음.
- **리포트/PDF** (macOS 허브 스샷 + `InspectionReport` 코드): navy 마스트헤드 + 위험색 밴드 + 면책 + monospaced 숫자. **출시 산출물로 전문적**(WO-5b). DESIGN_DIRECTION §7 정확 일치. 강점.
- **기록/목록·설정** (코드): 표준 폼/리스트, 빈·확인·오류 상태 3종 구비(설정 초기화 = 파괴적 role + 확인 + 오류 알럿). 양호.
- **macOS 대시보드·브라우즈·리포트허브** (스샷, populated): WO-8 폴리시로 쿨뉴트럴+navy+카드+위험칩 일관. 조망형 대시보드 = 역할 분리 준수. → F-6(경미).
- **앱 아이콘** (스샷): → F-3.

---

## 3. 이미 출시급 (강점 — 과잉 부정 방지)

- **위험등급 컬러칩 시그니처가 앱 전체에서 일관** — 홈 rail·위험요인·평가 밴드·점수칩·리포트 색밴드까지 한 언어. DESIGN_DIRECTION의 "단일 시그니처" 목표를 실제로 달성. anti-slop 통과.
- **쿨(navy=조작)/웜(위험=의미) 분리 철저** — 위험색을 장식으로 오용한 사례 발견 못 함. 위험색은 위험칩·등급선택·기한 긴급도(overdue=빨강)에만.
- **점검 실행·위험성평가 입력의 큰 탭타깃·라이브 파생** — 현장 도구로서 Fitts·Doherty를 실제로 만족(3단계 44pt, 빈도×강도 라이브 점수).
- **리포트가 제출 가능한 공식 문서 수준** — 제네릭 표 덤프가 아니라 마스트헤드·색밴드·면책·monospaced. 사용자가 공유하는 산출물의 완성도 높음.
- **라이트/다크 패리티** — iPhone·iPad·macOS 3표면 모두 다크 적응 확인.
- **면책 고지("기록이지 판정 아님")가 온보딩·설정·평가상세·리포트에 일관 노출** — 안전 도메인 신뢰·법적 안전의 핵심을 지킴(Nielsen #10 도움말/문서).

---

## 부록 A — Nielsen 10 요약 채점 (앱 전체)

| # | 원칙 | 상태 | 비고 |
|---|---|---|---|
| 1 시스템 상태 가시성 | 🟢 | 진행률 헤더·상태 배지·rail 카운트 |
| 2 시스템-현실 일치 | 🟡 | F-2 빈 문구 오표기 |
| 3 사용자 제어·자유 | 🟢 | 취소·삭제 확인·되돌리기(온보딩 재열기) |
| 4 일관성·표준 | 🟢 | 위험칩·폼·네비 일관 |
| 5 오류 예방 | 🟡 | 저장 disabled 가드 다수 · 단 F-1 첫실행 |
| 6 회상보다 인식 | 🟢 | 라벨·아이콘·프리필 |
| 7 유연성·효율 | 🟡 | F-5 Dynamic Type·단축키 제한 |
| 8 미학·미니멀 | 🟢 | dense-but-calm·절제 |
| 9 오류 복구 | 🟡 | 리셋 오류 알럿 有 · F-1 복구경로 확인 필요 |
| 10 도움말·문서 | 🟢 | 면책·빈상태 안내문 |

## 부록 B — 접근성 `확인 필요(수동)` — Accessibility Inspector / Dynamic Type 슬라이더 / Reduce Motion

- [ ] VoiceOver 스와이프 순서·라벨 완결성(위험칩·rail·세그먼트) — 코드상 `accessibilityLabel` 다수 존재하나 실제 리더 통독 필요
- [ ] Dynamic Type 최대 크기에서 홈 rail·체크리스트 버튼·리포트 레이아웃 깨짐 여부(F-5 연동)
- [ ] 대비 WCAG AA — 특히 위험색 위 흰 텍스트, `.secondary`/muted 텍스트, 다크모드 카드 경계
- [ ] Reduce Motion — 런치 인트로는 코드상 대응 확인(`ContentView.runIntroOnce`), 그 외 전환 확인
- [ ] (iPad) 회전·Slide Over(compact 전환 시 탭바 복귀), (macOS) 창 리사이즈·키보드 내비·메뉴바

---

## 부록 C — 커버리지 · 판정 요약

- **커버**: iPhone ✅ · iPad ✅ · macOS ✅ (각 라/다). iOS populated 플로우는 코드 정독 + macOS 리포트 스샷으로 보완.
- **blocks-launch**: **1건**(F-1, 검증 선행).
- **Top 5**: F-1(첫실행) → F-2(빈 문구) → F-3(아이콘) → F-4(freq×severity 타깃) → F-5(Dynamic Type).
- **출시 판정**: 🟡 **"이것만 고치고 출시"** — F-1 실기기 검증이 게이트. F-1 해소 + F-2 수정이면 출시 가능 수준. F-3~F-5는 출시 직후 패치도 허용 가능(F-3는 스토어 자료 영향이라 가급 출시 전).

*리뷰만 수행 — 코드 수정은 승인 후 별도 루프.*

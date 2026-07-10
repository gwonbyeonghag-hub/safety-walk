# V2_HANDOFF.md — SafetyWalk v2 작업 핸드오프 / 지시문 모음

> 이 문서는 **다른 섹션(별도 Claude 세션/작업자)** 이 실제 구현을 수행할 때 보는 작업지시서다.
> 계획·검토는 이 문서를 쓴 세션(이하 **플래너**)이 담당하고, **구현은 이 문서를 받는 섹션(이하 실행자)** 이 한다.
> 실행자는 이 대화의 맥락을 모른다고 가정한다. 모든 지시는 자기완결적으로 쓴다.

---

## 0. 프로젝트 식별 / 위치

| 항목 | 값 |
|---|---|
| 프로젝트 | SafetyWalk / 현장안전 지킴이 (산업안전 점검 앱) |
| git repo (코드) | `Desktop/02_개발/03_프로젝트/09_현장 안전 지킴이/현장 안전 지킴이/` |
| GitHub 원격 | `https://github.com/gwonbyeonghag-hub/safety-walk.git` (origin) |
| 기획 문서 (현재) | ✅ repo 루트에 편입 완료 (WO-0). `CLAUDE.md`/`V2_ROADMAP.md`/`CONTEXT.md` 등 + `docs/` + `.skills/` |
| 마스터 계획 | `V2_ROADMAP.md` (결정·아키텍처·빌드순서·사전요건) |
| 규칙 | `CLAUDE.md` (행동지침 + v2 규칙) |

---

## 1. 작업 프로토콜 (실행자 ↔ 플래너)

1. 실행자는 **작업지시(WO) 하나씩** 수행한다. WO 순서를 건너뛰지 않는다.
2. **착수 전 `/grill-with-docs`(없으면 수동)** — 코딩 시작 전에 이 WO를 `CLAUDE.md`·`DESIGN_DIRECTION.md`·**실제 코드**에 대고 갈아, **충돌·스테일 전제**(잘못된 파일경로·이미 red인 테스트·바뀐 API 등)를 찾는다. 발견하면 코딩하지 말고 **플래너에게 먼저 보고**. (예: WO-1의 "기존 39 green" 오류를 *착수 시점*에 잡기 — 작업 중이 아니라.)
3. **로직은 `/tdd` 레드-퍼스트** — 순수 로직(계산·매핑·상태 규칙·파싱: 예 매트릭스 밴드·리포트 페이지 패킹)은 **실패 테스트 먼저 → 통과**. UI·SwiftData·화면·리포트 레이아웃은 빌드 + 육안/스샷 검증(TDD 강제 아님 — 프로젝트가 디자인 비중 커서 로직에만 선별 적용).
4. 각 WO의 **수용 기준(Acceptance)** 을 **증거와 함께** 충족시킨다 — 빌드 로그 / 스크린샷 / `git diff` / 테스트 결과.
5. WO 완료 시 그 WO 섹션에 **결과 요약 + 증거 위치**를 적고 `[x]` 처리한다. 임의로 다음 WO로 넘어가지 않는다.
6. 막히거나 결정이 필요하면 **멈추고 질문**한다 (CLAUDE.md 행동지침 1: 가정 금지).
7. 플래너는 완료된 WO를 `V2_ROADMAP.md` / `CLAUDE.md` 규칙 대비 **검토**하고(빌드·테스트·스샷 **직접 재확인**, 러버스탬프 금지) 다음 WO를 연다.
8. **스코프 밖 작업 금지** — WO에 없는 "개선"·리팩터·기능 추가는 하지 않는다 (행동지침 2·3).

---

## 2. 빌드 순서 (요약 — 상세는 V2_ROADMAP.md §3)

```
WO-0  구조 재편 (repo 정리 + 문서 편입 + .gitignore)   ← 지금 / 0순위
WO-1  공유 패키지 SafetyWalkCore 추출                  (Apple 계정 불요)
WO-2  위험성평가 모듈 (4기법, iOS 먼저)                 (Apple 계정 불요)
WO-3  CloudKit 동기화                                  (iCloud 컨테이너 필요)
WO-4  네이티브 macOS 앱 (대시보드/리포트)               (macOS 앱 등록 필요)
WO-5  디자인·리포트 폴리시 + US(JHA)                    (스토어 자료)
WO-6  iOS+macOS 동시 제출                              (동시출시)
```

각 WO의 상세 지시는 플래너가 해당 단계 착수 시점에 이 문서에 추가한다.
**WO-0~3 ✅ v2 기능 완성 + 실기기 동기화 확인 · WO-8 macOS 디자인 폴리시 ✅ · WO-7 iPad 네이티브 레이아웃 ✅ · 앱 아이콘(안전모, iOS 라·다·틴티드+macOS) ✅ 완료 (2026-07-07).** 남은 것 = **App Store 동시출시(WO-6)** — WO-9 샌드박스+폴백 ✅ 완료(Release 크래시 소멸·F-1 해소). (F-1: iOS 실기기 첫 실행 정상 = 시뮬 전용 확정 → WO-9로 시뮬 온보딩도 정상화.)
> 📁 로컬 경로 변경: 프로젝트 폴더가 `02_개발/03_프로젝트/` → **`02_개발/02_프로젝트/`** 로 이동됨(2026-07-03, 손실 없음). GitHub 원격(`safety-walk`)이 안정 앵커.
(번호는 로드맵 순서, 실제 진행은 계정 의존성 따라 조정.)

---

## WO-0 — 구조 재편 (repo 정리 + 문서 편입) ✅ DONE (플래너 직접 수행, 2026-06-26)

**목적:** 코드만 들어있는 git repo에 기획문서·스킬·docs를 편입해 **단일 monorepo**로 만들고,
빌드 산출물이 커밋되지 않도록 `.gitignore`를 추가한다. 이후 모든 v2 작업의 토대.

**배경 (현재 문제):**
- 기획문서 12개(`CONTEXT/PRD/DOMAIN_TERMS/CLAUDE/V2_ROADMAP/TASKS/LAUNCH_CHECKLIST/SWIFTDATA_MIGRATION/
  APP_STORE_SUBMISSION/SUBMISSION_RUNBOOK/MONETIZATION_STRATEGY/POST_LAUNCH_MONETIZATION_VALIDATION`)
  + `docs/` + `.skills/` + `아이콘 이미지/` 가 모두 repo **바깥** 부모 폴더에 있어 GitHub에 없다.
- repo에 `.gitignore`가 없다 → `build/`, `xcuserdata`, `.DS_Store` 커밋 위험.
- repo에는 현재 **미커밋 변경**(런치 폴리시·아이콘·배포타깃 수정 등 실제 작업물)이 쌓여 있다 → 버리지 말고 정리 커밋.

**대상 구조 (목표):**
```
현장 안전 지킴이/                  ← git repo 루트 (= monorepo)
├── .gitignore                    (신규)
├── CLAUDE.md  V2_ROADMAP.md  V2_HANDOFF.md  CONTEXT.md  PRD.md
│   DOMAIN_TERMS.md  TASKS.md  LAUNCH_CHECKLIST.md  SWIFTDATA_MIGRATION.md
│   APP_STORE_SUBMISSION.md  SUBMISSION_RUNBOOK.md  MONETIZATION_STRATEGY.md
│   POST_LAUNCH_MONETIZATION_VALIDATION.md      (부모에서 이동)
├── docs/  .skills/  아이콘 이미지/             (부모에서 이동)
├── 현장 안전 지킴이.xcodeproj
└── 현장 안전 지킴이/ (Swift 소스)
    └── (미래) ../SafetyWalkCore/  ../macos/    ← WO-1·WO-4에서 추가
```

**절차 (순서 지킬 것):**
1. **현재 미커밋 변경 파악**: repo에서 `git status`, `git diff --stat` 확인. 변경의 의미를 한 줄씩 파악(런치/아이콘/pbxproj 등). **임의 폐기 금지.**
2. **`.gitignore` 먼저 추가** (커밋 전에). Xcode + SwiftPM + macOS 표준:
   `build/`, `DerivedData/`, `*.xcuserstate`, `**/xcuserdata/`, `.DS_Store`, `.swiftpm/`, `*.xcframework` 등.
   → `build/`, `*.xcuserstate`가 ignore되는지 `git status`로 확인.
3. **기존 작업물 정리 커밋**: 의미 있는 미커밋 변경(소스·pbxproj·assets)을 명확한 메시지로 커밋.
   (App.swift placeholder 삭제, ContentView 워드마크, 아이콘, 배포타깃 17.0 등 — 한 커밋 또는 논리 단위로.)
4. **문서·폴더 편입**: 부모 폴더(`09_현장 안전 지킴이/`)의 위 12개 `.md` + `docs/` + `.skills/` + `아이콘 이미지/`
   를 repo 루트로 이동(`mv`) 후 `git add`. (이들은 git 미추적 → `git mv` 아님, 일반 mv 후 add.)
   - 단, 부모/자식 폴더명이 둘 다 "현장 안전 지킴이"라 혼동 주의. 자식(repo)으로 넣는다.
   - `CLAUDE.md`는 repo 루트에 둔다(Claude Code 자동 로드 위치).
5. **커밋 + 푸시**: 문서 편입 커밋 후 `git push origin main`(또는 현재 브랜치).
6. **(선택, 후순위) 폴더 플랫화**: 부모/자식 이중 "현장 안전 지킴이" 중첩이 거슬리면 추후 정리.
   지금은 건드리지 않는다 (리스크). 이번 WO 범위 밖.

**Acceptance (증거 필수):**
- [x] `.gitignore` 존재, `git status`에 `build/`·`*.xcuserstate`·`.DS_Store` 안 보임
- [x] 기존 미커밋 작업물이 의미 있는 커밋으로 보존됨 (`bf63532`, 63파일)
- [x] 13개 기획문서 + `docs/` + `.skills/` 가 repo 안에 있고 추적됨 (`5fcd239`)
- [x] GitHub에 푸시 완료, 원격 main = `5fcd239` (CLAUDE.md·V2_ROADMAP.md 원격 확인)
- [x] iOS 앱 **빌드 그린** — `** BUILD SUCCEEDED **`

**하지 말 것:**
- repo의 기존 커밋 히스토리/원격을 새로 init 하거나 갈아엎지 말 것 (히스토리+remote 보존).
- 소스 코드 로직 변경 금지 (이 WO는 **구조/문서만**).
- WO-1(패키지 추출) 시작 금지 — WO-0 검토 통과 후 플래너가 WO-1을 연다.

**WO-0 결과:**
- 상태: ✅ 완료 (플래너 직접 수행, 2026-06-26)
- 발견(중요): repo의 유일 커밋 `d82fd08 Initial Commit`은 **빈 Xcode 템플릿**뿐 — 실제 앱 소스 42개(.swift)가 **전부 미추적**이었음(GitHub에도 없음). 구조 재편이 곧 v1 앱 최초 보존이 됨.
- 수행 커밋 (origin/main `5fcd239`까지 푸시 완료):
  - `03d1d1d` chore: `.gitignore` 추가(Xcode/SwiftPM/macOS) + `xcuserdata` 추적 해제 → `build/`(198MB)·xcuserdata 무시 확인(`check-ignore`)
  - `bf63532` feat: v1 앱 구현 전체 커밋 (63파일/+7952줄, Models/Views/ViewModels/Services/Utilities/템플릿/현지화/테스트/아이콘)
  - `5fcd239` docs: 기획문서 13개 + `docs/` + `.skills/` + `아이콘 이미지/`를 repo 루트로 편입
- Acceptance: `.gitignore` 작동(위험파일 스테이지 0), 작업물 보존, 문서 추적, **푸시 완료(원격=로컬 5fcd239)**, **iOS BUILD SUCCEEDED**(generic iOS Simulator, CODE_SIGNING_ALLOWED=NO) — 전부 충족.
- 남은 정리(선택, 후순위): 부모/자식 "현장 안전 지킴이" 폴더 이중 중첩 — 이번 범위 밖.

---

## WO-1 — 공유 패키지 `SafetyWalkCore` 추출 ✅ DONE (검수 통과 2026-06-27)

> 골격은 위키 워크플로우 지식 적용: 목표→범위→완료조건→중단조건→금지→검증 순서
> (`ai-agent-harness-engineering`·`ai-native-workflow-redesign`의 "위임 계약"),
> verifiable goal(`ai-agent-goal-command`), 자가 검증 루프 Trigger→State→Plan→Work→Evaluate→Gate→Memory
> (`ai-agent-loop-engineering`), 검토자 분리(`ai-code-review-quality-harness`).

### ⚖️ 플래너 결정 (2026-06-27) — 테스트 드리프트 해소 + 진행 지시
실행자가 발견·증명: 베이스라인(앱 미변경 상태)에서 이미 count 단언 4개가 red. 추출 전후 **실패집합 동일** → 추출이 만든 게 아님.
플래너 직접 검증(JSON 파싱): Korea **14카테고리/42항목**, Global **17/51**, 중복 0(category key·item id·titleKey 전부 유니크), 카테고리 키가 의미상 distinct(fall/electrical/fire/ppe/ladder/wws…). → 템플릿은 **의도된 확장**, 단언(3/11·4/12)은 구식 MVP 수치 = stale.
- **WO-1 성공기준 정정**: "기존 39 green 보존"은 잘못된 전제(실제 41테스트·이미 4 red). 추출의 올바른 기준 = **동작 중립(신규 실패 0)** → 이미 충족.
- **단언 갱신 승인 (Option 1, 단 분리 커밋)**: "단언 변경 금지"는 추출 실패를 테스트로 은폐 못하게 한 가드. 사전 red 증명됐으니 갱신은 정당한 부채정리 → 가드 해제. **추출 커밋과 분리된 별도 커밋**으로 4개를 실측치(KR 14/42·Global 17/51)로 수정.
- **Bundle 우회 승인**: `init(bundle: Bundle? = nil)` + 본문 `?? .module`는 SwiftPM 정석(`.module`은 internal이라 public 기본인자 불가). 동작 동일.
- **진행 지시**: 멈추지 말고 앱 통합까지 마무리 → ① 추출(동작중립) 커밋 ② 단언 갱신 커밋. 자세한 순서는 아래 본문.

### 배경 / 목적
v2는 iOS + 네이티브 macOS를 **하나의 데이터 모델·하나의 CloudKit 컨테이너**로 공유한다(V2_ROADMAP AD-1·AD-2).
별도 macOS 앱이 같은 모델을 쓰려면, 지금 iOS 앱 타깃 안에 박힌 **이식 가능한 코어**를 공유 Swift Package로 빼야 한다.
모델을 타깃별로 복붙하면 스키마 드리프트가 보장된다 → 그래서 추출이 1번 작업.

### 경로/이름 (혼동 주의: repo·소스 폴더가 동명)
- **repo 루트** = `09_현장 안전 지킴이/현장 안전 지킴이/` (monorepo, GitHub `safety-walk`)
- **APP/** (앱 소스 폴더, 이하 별칭) = repo 루트 안의 `현장 안전 지킴이/`
- Xcode 프로젝트 = `현장 안전 지킴이.xcodeproj` · **스킴/타깃** = `현장 안전 지킴이` · **테스트 모듈** = `현장_안전_지킴이`
- ⚠️ 스킴명은 한글 NFC/NFD 이슈로 `-scheme "현장 안전 지킴이"` 직접 타이핑이 안 먹는다.
  반드시 `xcodebuild -list` 출력에서 스킴명을 캡처해 변수로 넘길 것(검증 섹션 참고).

### 목표 (verifiable / 강한 기준)
APP의 **이식 가능한 코어**(모델·열거형·체크리스트 로더·템플릿 리소스)를 새 로컬 Swift Package
`SafetyWalkCore`로 옮기고, 앱 타깃이 그 패키지를 의존·`import`하게 한다.
**제약: 동작 변화 0. 추출(extract)만, 리팩터·재설계 금지. 빌드·테스트·앱 동작 그린 유지.**

| 약한 기준(쓰지 말 것) | 강한 기준(이걸로) |
|---|---|
| "패키지로 분리한다" | "아래 12개 파일이 `SafetyWalkCore/Sources/`로 이동, APP 타깃에서 멤버십 제거됨" |
| "빌드 잘 되게" | "`xcodebuild build` exit 0, 신규 warning 0" |
| "테스트 통과" | "추출 동작 중립 = 신규 실패 0 (사전 red 4개 외 새 실패 없음). 단언 갱신 커밋 후 full green" |
| "동작 동일" | "앱 실행→점검 시작→KR/Global 템플릿 항목이 그대로 로드, KO/EN 토글 정상" |

### 스코프

**✅ 포함 — `SafetyWalkCore`로 이동 (정확히 이것만):**
- `APP/Models/` 7개: `Area / ChecklistItem / ChecklistTemplate / Enums / Hazard / Inspection / Site .swift`
- `APP/Services/ChecklistTemplateLoader.swift` (`import Foundation`만 — 이식 가능 확인됨)
- `APP/Resources/Templates/checklist_korea.json`, `checklist_global.json` → 패키지 리소스로

**⛔ 제외 — 이번엔 APP에 그대로 (이유 = 증거 기반):**
- **Localization** (`Resources/Localization/*.lproj` + `Utilities/LocalizationKey.swift` + `LocalizationManager.swift`)
  → `LocalizationManager.swift:57`이 `Bundle.main.path(...ofType:"lproj")`로 **메인 번들 직접 조회**. 패키지로 옮기면 `Bundle.module`로 바뀌어 **조용히 깨짐**. 별도 WO에서 검증과 함께.
- `Services/PhotoStorageService.swift`(UIKit+ImageIO), `Services/InspectionExportService.swift`(SwiftUI+UIKit),
  `Utilities/Color+Risk.swift`(SwiftUI) → **UI 프레임워크 의존**. 크로스플랫폼화는 추출이 아니라 리팩터 → 별도 WO.
- `Utilities/RegionProfileStore.swift`, `LocalizationManager.swift`, `ViewModels/*`, `Views/*` → APP 잔류.

**🚫 절대 금지 (스코프 크리프 차단 — `ai-agent-harness-engineering` §2):**
- 새 프로토콜/Repository/추상화 설계, 모델 필드·이름 변경(`DOMAIN_TERMS.md` 위반), 로직 "개선",
  리소스 파일 내용 수정, macOS 타깃 생성/수정(그건 WO-4), CloudKit 관련 변경(WO-3), 새 기능.
- 기존 테스트의 단언 변경. (이동은 하되 내용 보존)

### 먼저: State 파악 (작업 전 실행 — `ai-agent-loop-engineering`)
```bash
REPO="…/09_현장 안전 지킴이/현장 안전 지킴이"; APP="$REPO/현장 안전 지킴이"
ls "$APP/Models" "$APP/Services" "$APP/Resources/Templates"      # 이동 대상 실재 확인
git -C "$REPO" status -s | wc -l                                   # 0 (깨끗에서 시작)
git -C "$REPO" switch -c wo1-extract-safetywalkcore                # 전용 브랜치에서 작업
```

### 작업 단계 (Plan→Work). 각 단계 후 빌드로 확인하며 전진.
1. **로컬 패키지 생성**: repo 루트에 `SafetyWalkCore/` (`Package.swift` + `Sources/SafetyWalkCore/`).
   `Package.swift`: `platforms: [.iOS(.v17), .macOS(.v14)]`, 라이브러리 product `SafetyWalkCore`,
   타깃 resources에 `.process("Resources")`.
2. **파일 이동**: 위 7개 모델 + `ChecklistTemplateLoader.swift` → `Sources/SafetyWalkCore/`.
   템플릿 2개 JSON → `Sources/SafetyWalkCore/Resources/`.
3. **접근 제어(public화) — 추출의 핵심 노동, 리팩터 아님**: 단일 모듈에선 전부 `internal`이라 import만으론 안 보인다.
   앱이 쓰는 **모든 이동 타입과 멤버를 `public`** 으로:
   - `@Model final class`(Site/Area/Inspection/ChecklistItem/Hazard) → `public`, **저장 프로퍼티·`init` 모두 `public`**
     (SwiftData `@Model` + public init 조합이 컴파일되는지 즉시 빌드 확인).
   - `enum`(Enums.swift 전부), `ChecklistTemplate`(+ Codable 멤버), `ChecklistTemplateLoader`(`public struct`/`public init`/`public func load`), 앱이 참조하면 `ChecklistTemplateLoaderError`도.
4. **Bundle.module**: `ChecklistTemplateLoader.init(bundle: Bundle = .main)` → **`.module`** 로 기본값 변경
   (테스트는 번들 주입식이라 영향 없음).
5. **pbxproj 수술**: APP 타깃에서 이동한 12파일 **멤버십 제거** + `SafetyWalkCore`를 **로컬 패키지 의존성으로 추가**하고 product 링크.
   → 가능하면 **Xcode UI 권장**(파일 Remove Reference → File>Add Package Dependencies>Add Local). 수기로 pbxproj 편집 시 반드시 빌드로 검증. (가장 깨지기 쉬운 단계.)
6. **import 추가**: 이동 타입을 참조하는 **모든 APP 파일에 `import SafetyWalkCore`** (SafetyWalkApp/ContentView/대부분 Views·ViewModels/PhotoStorage·Export 서비스 등). 빌드 에러가 가이드 역할.
7. **테스트 이전**: `ChecklistTemplateLoaderTests.swift` → 패키지 테스트 타깃 `Tests/SafetyWalkCoreTests/`로 이동, `@testable import 현장_안전_지킴이` → `import SafetyWalkCore`. (`PhotoStorageServiceTests`는 서비스가 APP 잔류이므로 그대로 둔다.)

### 완료 조건 (전부 증거와 함께 — 하나라도 red면 미완료)
- [ ] `SafetyWalkCore/Package.swift` + `Sources/SafetyWalkCore/`에 12파일(모델7+로더1+JSON2 = 10 실파일, 폴더 포함) 존재
- [ ] APP 타깃에 이동 파일 **잔존 0**: `find "$APP/Models" "$APP/Services/ChecklistTemplateLoader.swift" -type f 2>/dev/null | wc -l` → 0
- [ ] 패키지 단독 빌드 green / 앱 빌드 `** BUILD SUCCEEDED **`, **신규 warning 0**
- [ ] 테스트: 추출은 신규 실패 0(동작 중립) → 그 뒤 **별도 커밋**으로 stale 단언 4개(KR 14/42·Global 17/51) 갱신 → 패키지+앱 테스트 full green
- [ ] 앱 실행: **점검 시작 → KR/Global 템플릿 항목 정상 로드**(=`Bundle.module` 성공), KO/EN 토글 정상(=localization 안 깨짐)
- [ ] `git status` 깔끔(의도 변경만), `import SafetyWalkCore` ≥ 1 (`grep -rl "import SafetyWalkCore" "$APP" | wc -l`)
- [ ] 보고: 이동 파일 목록 / public화한 타입 목록 / import 추가 파일 수 / 빌드·테스트 결과

### 중단 조건 (하나라도 발생 → 멈추고 보고. 억지 진행 금지)
- SwiftData `@Model`+`public`이 매크로 에러를 낸다 (해결책 불명확)
- pbxproj 수술 후 빌드가 회복 불가하게 깨진다 → 변경 전 커밋으로 복구하고 상태 보고
- 템플릿이 런타임에 로드 안 됨(`Bundle.module` 리소스 누락) / localization이 깨진다
- 순환 의존(코어가 APP 타입을 역참조해야 하는 상황) 발견 → 그래프와 함께 보고
- 도구/환경 문제(Xcode 버전·SPM)

### 검증 명령
```bash
REPO="…/현장 안전 지킴이"; PROJ="$REPO/현장 안전 지킴이.xcodeproj"
SCHEME=$(xcodebuild -project "$PROJ" -list 2>/dev/null | awk '/Schemes:/{f=1;next} f&&NF{sub(/^ +/,"");print;exit}')  # NFC/NFD 회피
xcodebuild -project "$PROJ" -scheme "$SCHEME" -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
# 테스트는 부팅 시뮬 destination 지정해서 xcodebuild test
# 앱 실제 실행/화면 확인은 프로젝트 .skills 활용(아래)
```

### Skills 호출 지점 (프로젝트 `.skills/` + 공용)
- `/swiftui-build-qa` — 빌드/경고 검증 단계마다
- `/safetywalk-qa-guardrails` — 스코프·도메인 규칙 위반 자가점검
- `/checklist-template-expansion` — 템플릿 리소스 이동 후 로딩 정상 확인(KR/Global)
- 빌드가 막히면 `/diagnose`, 완료/중단 직전 `/handoff`로 상태 정리
- (UI 변경 없으므로 `/design-visual-qa`·`/navigation-qa`는 최종 스모크만)

### 보고(handoff) 형식 — 완료/중단 시 이 형태로
```
WO-1 결과: [완료 | 중단(사유)]
- 브랜치/커밋: wo1-extract-safetywalkcore @ <sha>
- 이동 파일: [목록]   public화: [타입 목록]   import 추가: <n>개 파일
- 빌드: <SUCCEEDED/FAILED>  테스트: <pass/total>  앱 동작: <템플릿 로드/localization 확인 결과>
- 막힌 점/해결: …   다음 WO 제안: …
```

**WO-1 결과: ✅ 완료 (실행자 수행 + 플래너 검수 통과, 2026-06-27)**
- 브랜치 `wo1-extract-safetywalkcore` → main 머지:
  - `0b47f55` 추출(동작 중립) — 40파일/+180−102
  - `6d1fb43` stale 단언 4개 갱신 (KR 14/42 · Global 17/51)
- 이동: 모델7(Site/Area/Inspection/ChecklistItem/Hazard/Enums/ChecklistTemplate) + `ChecklistTemplateLoader` + JSON2 → `SafetyWalkCore/Sources/`. **JSON 체크섬 원본과 바이트 동일**.
- public화: @Model 클래스5(프로퍼티·init 전부) / enum7 / struct3 / 로더+에러. `import SafetyWalkCore` 26개 앱 파일.
- Bundle: `init(bundle: Bundle? = nil) { … ?? .module }` (SwiftPM 정석, 동작 동일).
- pbxproj: 동기화 그룹(PBXFileSystemSynchronizedRootGroup)이라 멤버십 자동 해제 + `XCLocalSwiftPackageReference` 3조각. plutil OK.
- **플래너 독립 검증**: 커밋② = 테스트 단언만 변경(JSON·로직 혼입 0) / 파일이동·체크섬·pbxproj 확인 / 패키지 `swift test` **26/26** / 앱 `xcodebuild build` **BUILD SUCCEEDED** / 앱 테스트 15/15(실행자).
- STOP 리스크 전부 해소: @Model+public ✅ · Bundle.module ✅ · 0 warning ✅ · 동작 중립 ✅.
- 범위 밖(미실행): 체크리스트 화면까지 UI 탭다운 인터랙션 스크립트화 안 함(WO: UI 최종 스모크만). 런타임 Bundle.module 경로는 패키지 로딩 테스트 22개로 증명됨.

---

## WO-2 — 위험성평가 모듈 (3단계 + 빈도×강도 3x3) ✅ DONE (검수 통과 2026-06-27)

> 골격은 WO-1과 동일(위키 위임계약·verifiable goal·자가검증 루프·검토자 분리).
> WO-1과 차이: 이건 **추출이 아니라 신규 기능** → 성공기준은 "동작 중립"이 아니라 "수용기준 충족 + 회귀 0".
> 오너 결정(2026-06-27): **2기법만**(3단계 상·중·하 + 빈도×강도), 매트릭스 **3x3**(데이터로 추상화 → 추후 5x5).
> 체크리스트법·JSA = WO-2b. CloudKit 배선 = WO-3(단, 모델은 지금 CloudKit-ready로).

### 배경 / 목적
한국 산안법상 위험성평가는 정기(≥연1회)+최초+수시로 요구된다(V2_ROADMAP AD-3). 현재 앱엔 전무.
점검(Pass/Fail/NA)·위험요인(즉시기록)과 **별개**의 정식 평가표를 만든다. 앱은 **기록/리마인더**만, **법적 판정 안 함**(면책 고지 필수).

### 목표 (verifiable / 강한 기준)
`SafetyWalkCore`에 `RiskAssessment`/`RiskAssessmentItem` 모델(**CloudKit-ready**)을 추가하고,
iOS에서 **2기법으로 위험성평가표를 생성→항목입력→위험성 산정→감소대책→저장→목록/상세**까지 완결한다.
- 3단계: 위험성 수준을 상/중/하 **직접 선택**(기존 `RiskLevel` 재사용).
- 빈도×강도: 가능성(1–3)×중대성(1–3) → **점수 1–9 → 밴드(상/중/하) 자동 파생**(데이터 기반 매트릭스).

### 스코프

**✅ 포함:**
- **모델(SafetyWalkCore)** — 아래 §모델 스펙대로. 전 속성 optional/기본값, 관계 optional, `.unique` 금지(CloudKit-ready).
- **매트릭스 설정(데이터)** — 3x3 밴드 경계를 **값/설정으로**(코드 if문에 하드코딩 금지, CLAUDE.md 규칙). 5x5는 이 값만 바꿔 확장 가능하게.
- **iOS UI** — 생성 플로우(평가종류·기법·현장·평가자) → 항목 입력(기법별 위험성 입력) → 목록/상세. Home에서 **2탭 이내 도달**.
- **현지화** — 신규 문자열 EN/KO 키 패리티(`LocalizationKey`).
- **테스트** — 매트릭스 밴드 로직(3x3 전 조합) + 모델 단위 테스트(SafetyWalkCoreTests).
- **DOMAIN_TERMS.md 갱신** — 신규 용어(아래) 먼저 등재.

**⛔ 제외 (별도 WO):**
- 체크리스트법·JSA(WO-2b) · CloudKit 배선(WO-3) · 이쁜 위험성평가표 PDF/인쇄(WO-5) · macOS(WO-4) · 연1회 due 알림 로직(후속). WO-2의 리포트는 **기본 요약 화면**까지만.

**🚫 절대 금지:** 기존 모델 필드 변경, 점검(Inspection)에 점수 도입(점검은 Pass/Fail/NA 유지), 법적 적합/위반 판정 문구, 도메인 용어 임의 신설(DOMAIN_TERMS.md 경유), 네비게이션 대수술.

### 신규 도메인 용어 (DOMAIN_TERMS.md에 먼저 추가)
| EN(code) | KO(UI) | 정의 |
|---|---|---|
| RiskAssessment | 위험성평가 | 한 건의 평가표. 종류·기법·현장·평가자·항목들 보유 |
| RiskAssessmentItem | 위험성평가 항목 | 공정/작업·유해위험요인·현재조치·위험성·감소대책·개선후·담당/기한 |
| RiskAssessmentKind | 평가종류 | `initial`최초 / `regular`정기 / `occasional`수시 |
| RiskAssessmentMethod | 평가기법 | `threeLevel`3단계 / `frequencySeverity`빈도×강도 (추후 checklist/jsa) |
| Likelihood | 가능성(빈도) | 빈도×강도 입력 1–3 |
| Severity | 중대성(강도) | 빈도×강도 입력 1–3 |
| RiskScore | 위험성 점수 | 가능성×중대성 (1–9) |
| (band) | 위험성 수준 | 상/중/하 = 기존 `RiskLevel` 재사용 |
| ReductionMeasure | 감소대책 | 위험성 감소 조치 |

### 모델 스펙 (SafetyWalkCore, public, CloudKit-ready)
```swift
@Model public final class RiskAssessment {
  public var id: UUID = UUID()
  public var kind: RiskAssessmentKind = .regular
  public var method: RiskAssessmentMethod = .frequencySeverity
  public var siteId: UUID?                 // optional link
  public var siteName: String = ""         // denormalized(이력 보존, Inspection 패턴)
  public var assessorName: String = ""
  public var assessedAt: Date = .init()    // init에서 현재시각
  public var note: String?
  public var linkedInspectionId: UUID?     // optional
  @Relationship(deleteRule: .cascade) public var items: [RiskAssessmentItem]?  // optional(CloudKit)
}
@Model public final class RiskAssessmentItem {
  public var id: UUID = UUID()
  public var taskDescription: String = ""       // 공정/작업
  public var hazardDescription: String = ""     // 유해위험요인
  public var currentControls: String?           // 현재 안전조치
  public var likelihood: Int?                    // 가능성 1–3 (빈도×강도 전용; 3단계는 nil)
  public var severity: Int?                      // 중대성 1–3
  public var riskLevel: RiskLevel = .low         // 위험성 수준(3단계=직접/빈도×강도=점수→파생)
  public var reductionMeasure: String?           // 감소대책
  public var postRiskLevel: RiskLevel?           // 개선 후 위험성(선택)
  public var responsibleName: String?            // 담당
  public var dueDate: Date?                       // 개선예정일
  public var correctiveActionStatus: CorrectiveActionStatus = .notStarted  // 기존 enum 재사용
  public var linkedHazardId: UUID?               // optional link to Hazard
}
```
- `riskLevel`은 항상 **resolved 위험성 수준**. 빈도×강도는 `score = (likelihood ?? 0)*(severity ?? 0)` → 밴드 파생해 저장. 3단계는 사용자가 직접.
- **매트릭스 설정(데이터)** — `RiskMatrixConfig`(public struct, 값): `likelihoodScale=3, severityScale=3`, 밴드 경계 **필드로**: 3x3 기본 `score ≤2→.low / 3…4→.medium / ≥6→.high`(곱값은 1,2,3,4,6,9뿐). `func band(forScore:)`. 경계가 **데이터**라 5x5는 이 값만 교체.

### UI / 기능 (기능 수용기준 — 화면 디자인 latitude는 실행자, 단 QA 스킬 통과)
- **진입**: Home에서 "위험성평가" 도달 ≤2탭(탭 추가 or Home 카드 — 실행자 판단, `/navigation-qa` 필수).
- **생성**: 평가종류(최초/정기/수시) + 기법(3단계/빈도×강도) + 현장(기존 Site 피커, optional) + 평가자명.
- **항목 입력**: 행 추가. 공통(공정/작업·유해위험요인·현재조치·감소대책·담당·기한·상태). 위험성 입력은 **기법별**:
  - 3단계 → 상/중/하 색상 버튼(기존 `Color+Risk` 재사용).
  - 빈도×강도 → 가능성1–3 × 중대성1–3 선택 → **실시간 점수+파생 밴드 색상 표시**.
- **목록/상세**: 평가 목록(일자·현장·기법·항목수·위험성 분포), 상세는 항목별 위험성 색 밴드. **면책 고지 노출**(기존 재사용).
- **현지화**: 신규 문자열 EN/KO 동시.

### 완료 조건 (증거 필수)
- [ ] DOMAIN_TERMS.md에 신규 용어 등재 / `RiskAssessment`·`RiskAssessmentItem` 모델이 SafetyWalkCore에 추가, 전 속성 optional/기본값·관계 optional·`.unique` 없음(CloudKit-ready)
- [ ] 매트릭스 밴드 경계가 **데이터/설정**(if문 하드코딩 아님)
- [ ] 패키지 테스트: 3x3 전 조합 점수→밴드 + 3단계 pass-through 단위테스트 green
- [ ] iOS 2기법 end-to-end: 생성→항목입력→위험성 산정(3단계 직접/빈도×강도 파생)→저장→목록→상세, **시뮬레이터 런타임 검증**(스크린샷/SwiftData 확인)
- [ ] 신규 문자열 EN/KO 패리티 / 면책 고지 노출
- [ ] 앱 빌드 green, **기존 41테스트 회귀 0**(WO-1 베이스라인 유지)
- [ ] `/navigation-qa`·`/screen-implementation-review`·`/design-visual-qa`·`/safetywalk-qa-guardrails` 통과
- [ ] 보고: 신규 모델·용어, 매트릭스 설정 위치, 추가 화면, 빌드/테스트, 런타임 검증 증거

### 중단 조건
- SwiftData `@Model` CloudKit-ready 제약 충돌(해결 불명확) / 네비게이션이 대수술 필요 / 한국 위험성평가 의미론 모호(예: 밴드 경계 분쟁) / 기존 테스트 회귀.

### 검증 (WO-1과 동일 + 시뮬 런)
스킴은 `xcodebuild -list`에서 캡처(NFC/NFD). 패키지 `swift test`, 앱 `xcodebuild build`/`test`, 시뮬 실행으로 2기법 플로우.

### Skills 호출 지점
`/swiftui-build-qa`(빌드), `/navigation-qa`(진입/전환), `/screen-implementation-review`(화면 완료 전), `/design-visual-qa`(이쁘게 — 렌더→스샷→비평), `/safetywalk-qa-guardrails`(스코프·법적문구·도메인). 막히면 `/diagnose`, 완료/중단 전 `/handoff`.

### 진행 / 보고
**main에서 새 브랜치**(예: `wo2-risk-assessment`)로 작업. WO-1 handoff 형식으로 보고 → 플래너 검수 → WO-2b/ WO-3.

**WO-2 결과: ✅ 완료 (실행자 수행 + 플래너 검수 통과, 2026-06-27)**
- 브랜치 `wo2-risk-assessment` → main 머지: `288167f` core(모델+매트릭스), `224e724` iOS(화면+현지화+영속)
- 모델(SafetyWalkCore, **CloudKit-ready 검증 ✅**): RiskAssessment/RiskAssessmentItem 전 속성 optional·기본값, 관계 optional, `.unique` 없음. enum 2종(Kind/Method) 추가(기존 enum 무변경). DOMAIN_TERMS 등재.
- 매트릭스(데이터): `RiskMatrixConfig.threeByThree` = `[≤2 .low / ≤4 .medium / .max .high]`, `band(forScore:)` 순회. 5x5는 config 교체만.
- iOS: Home 카드 → 목록/상세/생성/항목에디터(3단계 색버튼 · 빈도×강도 실시간 점수+밴드칩). 면책 고지 노출. EN/KO +37/+37 패리티.
- **플래너 독립 검증**: 기존 코어 모델 무변경 · 스코프 클린(CloudKit/macOS/PDF/checklist·JSA 무손댐) · 패키지 `swift test` **35/35** · 앱 `xcodebuild build` **BUILD SUCCEEDED**. 실행자 보고(앱 18/UITest 2, 회귀 0)와 정합.
- 엔지니어링 노트: VM SwiftUI-free 유지(IndexSet 제거), UITest가 실 네비버그(value-based NavigationLink 미등록) 포착·수정.

---

## WO-2b — 위험성평가 기법 추가 (체크리스트법 + JSA/JHA) ✅ DONE (검수 통과 2026-06-27)

> WO-2 모듈에 기법 2종을 얹는 **저위험 추가작업**. Apple 계정과 무관 → CloudKit 활성화 대기 중 진행.
> WO-2의 `RiskAssessment`/`RiskAssessmentItem`·`RiskMatrixConfig`·화면을 **재사용·확장**(재작성 금지). 골격은 WO-1/2와 동일.

### 배경 / 목적
오너 결정으로 위험성평가는 4기법(V2_ROADMAP AD-3). WO-2가 3단계+빈도×강도를 깔았다. 이번에
**체크리스트법(한국 — 점검 연계)** + **JSA/JHA(해외/미국)**를 추가해 4기법 완성. JSA는 Global 프로파일의 해외 위험성평가에 대응(AD-6).

### 목표 (verifiable)
`RiskAssessmentMethod`에 `checklist`·`jsa`를 추가하고, iOS에서 **두 기법으로 평가 생성→입력→저장→목록/상세**까지 완결. **기존 2기법·기존 테스트 회귀 0.**

### 스코프

**✅ 포함:**
- enum `RiskAssessmentMethod`에 `.checklist`, `.jsa` 추가.
- 모델: `RiskAssessmentItem`에 **`sortOrder: Int = 0`** 추가 — JSA 단계 순서용(+ CloudKit는 to-many 순서 미보장이라 명시적 순서 필드 필요, ChecklistItem과 동일 이유). **기본값이라 CloudKit-safe.** 그 외 모델 변경 없음.
- **체크리스트법** = 기존 **Inspection 연계**: 완료된 점검을 골라 그 체크리스트 항목(특히 **부적합/Fail**)을 평가 항목으로 **시드** → 항목별 위험성(3단계 상/중/하) + 감소대책. `linkedInspectionId`(평가)·`linkedHazardId`(항목) 재사용. 점검 항목→평가 항목은 **텍스트 복사**(하드 링크 불필요).
- **JSA/JHA** = 작업을 **순서 있는 단계**로: 각 단계(작업단계)→유해위험요인→현재/권장 안전조치→위험성 등급. US/OSHA 친화 라벨(해외). 위험성 입력은 기존 컴포넌트 재사용.
- 생성 플로우·항목 에디터·상세에 두 기법 **분기 추가**(기존 화면 확장, 재작성 X).
- 신규 문자열 **EN/KO 패리티**. 면책 고지 유지.
- **DOMAIN_TERMS.md**에 신규 기법·JSA 용어(작업단계 등) 등재.
- 테스트: 신규 enum·`sortOrder` 기본값·체크리스트 시드 로직·JSA 단계 정렬 유지.

**⛔ 제외:** CloudKit(WO-3) · macOS(WO-4) · 이쁜 PDF(WO-5) · 기존 2기법 동작 변경 · 점검(Inspection)에 점수 도입.

**🚫 금지:** 기존 모델 필드 **의미/이름** 변경(sortOrder 추가만 허용), 도메인 용어 임의 신설(DOMAIN_TERMS 경유), 네비게이션 대수술.

### 설계 메모 (모델은 이미 거의 수용 — 추가는 sortOrder뿐)
- `RiskAssessmentItem`의 taskDescription(작업/단계)·hazardDescription·currentControls·reductionMeasure·riskLevel·likelihood/severity가 두 기법을 이미 담는다.
- 위험성 입력: **체크리스트법 → 3단계(상/중/하)** 권장(점검 부적합→위험성 판단에 자연스러움). **JSA → 빈도×강도**(단계별 점수) 권장. 단 latitude 허용 — `/screen-implementation-review`로 자연스러운 쪽 선택, riskLevel로 resolved 저장만 지키면 됨.
- 지역(AD-6): 생성 시 기법 목록을 region으로 정렬/기본값 가능(KR→빈도×강도/3단계/체크리스트, Global→JSA). 간단히, 강제 아님.

### 완료 조건 (증거 필수)
- [ ] enum 2종 추가 / `sortOrder` 추가(기본값, CloudKit-safe) / 기존 모델 그 외 무변경
- [ ] 체크리스트법: 점검 선택 → 부적합 항목 시드 → 위험성+대책 → 저장, **시뮬 런타임 검증**
- [ ] JSA: 순서 있는 단계 입력(**정렬 유지**) → 하자드/조치 → 저장, **시뮬 런타임 검증**
- [ ] 목록/상세에서 **4기법 모두** 정상 표시 / 면책 고지 노출
- [ ] 신규 문자열 EN/KO 패리티 / DOMAIN_TERMS 갱신
- [ ] 앱 빌드 green, **기존 테스트 회귀 0**(WO-2 기준 55 + 신규)
- [ ] `/swiftui-build-qa`·`/navigation-qa`·`/screen-implementation-review`·`/design-visual-qa`·`/safetywalk-qa-guardrails`
- [ ] 보고: 신규 enum·sortOrder·두 기법 화면·테스트·런타임 증거

### 중단 조건
- 체크리스트 시드가 모델/화면 대수술을 요구 / JSA 순서가 `sortOrder`만으로 부족 / 한국·미국 위험성평가 의미론 모호 → 멈추고 질문.

### 진행 / 보고
**main에서 새 브랜치 `wo2b-risk-methods`.** WO-1 handoff 형식으로 보고 → 플래너 검수 → (계정 활성화됐으면) WO-3.

**WO-2b 결과: ✅ 완료 (실행자 수행 + 플래너 검수 통과, 2026-06-27)**
- 브랜치 `wo2b-risk-methods` → main 머지: `bce1d1e` core(`.checklist`/`.jsa` + `usesFrequencySeverity` + `sortOrder`), `2939666` iOS(체크리스트 시드·JSA 단계·화면 확장)
- **코어 변경 최소**: enum 2케이스+분류 / RiskAssessmentItem += `sortOrder: Int = 0`(CloudKit-safe). **RiskAssessment·v1모델·매트릭스 무변경.**
- 체크리스트법: 완료 점검 선택 → 부적합 항목 시드(`linkedInspectionId`/`linkedHazardId` 재사용) → 3단계. JSA: 순서 있는 작업단계(`sortOrder`) → 빈도×강도.
- **플래너 독립 검증**: 스코프 클린(CloudKit/macOS/PDF 무손댐·기존 2기법 무변경) · RiskAssessmentItem=sortOrder만 · EN/KO +10/+10 · DOMAIN_TERMS 갱신 · 패키지 `swift test` **39/39** · 앱 **BUILD SUCCEEDED** · 회귀 0(WO-2 55 유지, 총 64).
- 엔지니어링 노트: VM SwiftUI-free 유지(드래그 재정렬은 범위 밖 — "정렬 유지"는 `sortOrder`로 충족), UITest가 segmented→menu 회귀·KO 라벨 버그 자가포착·수정.
- 잔여(경미, 수용): 실제 점검 연계 시드의 풀-스크린샷은 테스트 스토어에 완료 점검 0이라 미캡처 — 시드 정확성(부적합만·링크·등급)은 SwiftData 통합테스트 2건으로 검증됨.
→ **위험성평가 4기법 완성.**

---

## WO-3 — CloudKit 동기화 (iPhone↔Mac 데이터 공유) ✅✅ DONE + 실기기 동기화 확인 완료 (2026-07-07)

> **✅ 실기기 검증 완료 (오너, 2026-07-07):** 아이폰(실기기)에서 위험성평가("동기화테스트") 생성 → macOS Release(CloudKit) 앱에 **실제로 나타남** 확인. iPhone→Mac CloudKit 동기화 end-to-end 작동. (iPad는 동일 유니버설 앱+컨테이너라 동일 동작.)

> **✅ Phase A 완료 (플래너 직접 수행):** 근본원인 = 번들 `com.safetywalk.app` **선점(사용불가)**. → **고유 ID로 변경**: iOS `com.gwonbyeonghag.safetywalk` / macOS `com.gwonbyeonghag.safetywalk.mac`(+ 테스트). **CloudKit 컨테이너 = `iCloud.com.gwonbyeonghag.safetywalk`** (엔타이틀먼트 `SafetyWalk_iOS.entitlements`·`SafetyWalkMac/SafetyWalkMac.entitlements`, Push/aps는 뺌 = **CloudKit only**, 실시간 푸시는 후속). 두 타깃 `-allowProvisioningUpdates` 빌드 성공 → App ID 등록·iOS/Mac Team 프로파일 생성·컨테이너 생성·기기 등록 완료. 커밋 `d2ccda1`. **실행자는 이제 CloudKit 코드 배선(ModelContainer CloudKit swap + v1 모델 5종 retrofit)만.** 아래 본문의 컨테이너 ID는 전부 `iCloud.com.gwonbyeonghag.safetywalk`로 읽는다.

> **🔄 업데이트 (2026-07-03) — 계정 Active + macOS 앱이 이미 존재. 아래 본문의 "iOS 타깃/앱" 언급은 iOS+macOS 양쪽으로 읽는다:**
> ① Apple Developer 계정 **활성화 완료** → Phase A 진행 가능 (Xcode Settings→Accounts에 **유료팀 로그인 확인** 먼저; 안 뜨면 Xcode 재시작).
> ② **이제 앱이 둘**(iOS `현장 안전 지킴이` + macOS `SafetyWalkMac`) → WO-3는 **두 앱 모두** CloudKit로 연결:
> &nbsp;&nbsp;• **두 타깃 각각** iCloud→CloudKit capability + **동일 컨테이너 `iCloud.com.safetywalk.app`** + Background Modes(Remote notifications) → 엔타이틀먼트 2개.
> &nbsp;&nbsp;• iOS `SafetyWalkApp` 컨테이너 **와** macOS `MacModelContainer`(WO-4가 만든 단일 스왑 지점) **둘 다** CloudKit-backed로.
> &nbsp;&nbsp;• v1 모델 5종 retrofit·사진 externalStorage·VersionedSchema 마이그레이션은 **공유 SafetyWalkCore라 한 번만**(양 앱 자동 공유).
> ③ 검증 = **실제 iPhone↔Mac**(같은 iCloud 로그인): 아이폰에서 점검/위험요인/위험성평가(사진) 생성 → **Mac 대시보드·브라우즈에 실제로 나타남**. (WO-4 시드는 `#if DEBUG`라 실데이터와 분리.)

> 골격은 WO-1/2와 동일(위임계약·verifiable goal·자가검증·검토자 분리).
> 이건 **인프라 + 스키마 변경**이 얽힌 묵직한 WO다. Phase로 나눠 진행하고, 막히면 멈춰라.
> CloudKit 배선 = 이번 WO. **iOS·macOS 두 앱 모두** 대상.

### 배경 / 목적
iPhone↔Mac 연동의 핵심(V2_ROADMAP AD-2). **오프라인 우선은 유지**(비행기모드로도 점검 완결) — 그 위에 CloudKit 동기화 계층을 얹는다. macOS 앱(WO-4)이 같은 데이터를 보려면 이게 전제. 모든 모델은 WO-1/2에서 이미 일부 CloudKit-ready이나, **v1 모델 5종은 아직 비호환** → 이번에 retrofit.

### ⚠️ Phase A — 오너 사전작업 (Apple 계정 필요)
- **유료 Apple Developer 계정이 Xcode에 로그인**돼 있어야 함(앱이 제출 직전이었으니 보유 추정).
- Xcode → Target `현장 안전 지킴이` → Signing & Capabilities → **+ Capability → iCloud → CloudKit 체크** → 컨테이너 **`iCloud.com.safetywalk.app`**(번들 `com.safetywalk.app` 기준) 생성/선택.
- **+ Capability → Background Modes → Remote notifications** 체크(푸시 기반 동기화).
- 실행자가 Xcode에서 시도 가능하나, **계정/결제 벽이면 멈추고 오너에게 요청**(중단조건).
- 산출: 엔타이틀먼트 파일에 iCloud 컨테이너 + `aps-environment` + background modes.

### 목표 (verifiable)
앱이 CloudKit **private DB**로 동기화된다. **같은 iCloud 계정의 기기A에서 만든 점검/위험요인/위험성평가(사진 포함)가 기기B에 나타난다.** 오프라인 단독 완결성 유지, 기존 55테스트 회귀 0.

### 스코프

**✅ 포함:**
- Phase A 엔타이틀먼트/capability.
- **v1 모델 5종 CloudKit 호환 retrofit** — 모든 저장 프로퍼티에 기본값, 모든 관계 optional (정확 목록 아래).
- **사진 동기화** — `Hazard`/`ChecklistItem` 사진을 `@Attribute(.externalStorage) var photoData: Data?`로 → CKAsset 자동 동기화. 기존 파일 사진(`photoPath` → `Documents/EvidencePhotos/`) 마이그레이션. `PhotoStorageService`·표시부 갱신.
- ModelContainer를 **CloudKit-backed**로(`ModelConfiguration(..., cloudKitDatabase: .private("iCloud.com.gwonbyeonghag.safetywalk"))` 또는 `.automatic`).
- 관계 optional화 **ripple 처리**: `.items`/`.areas`/`.hazards` 접근부 `?? []`.
- **VersionedSchema v1→v2 마이그레이션** + `SWIFTDATA_MIGRATION.md` 갱신.
- **2-시뮬레이터(같은 iCloud 로그인) 동기화 검증.**

**⛔ 제외:** macOS 앱(WO-4) · CloudKit **공유DB/다중사용자**(v2 밖) · 커스텀 충돌해결(기본 last-writer-wins 사용) · 푸시 알림 UI · WO-2b(체크리스트법·JSA).

**🚫 금지:** 도메인 로직 변경, 화면 재설계, 기존 모델 **필드 의미** 변경(기본값 추가는 OK, 의미·이름 변경 금지), `.unique` 추가.

### retrofit 정확 목록 (전부 기본값 부여 + 관계 optional化)
| 모델 | 기본값 줄 프로퍼티 | 관계 → optional |
|---|---|---|
| Site | id=UUID(), name="", createdAt=Date() | `areas: [Area]?` |
| Area | id=UUID(), name="", siteId(기본/optional) | — |
| Inspection | id, siteId, siteName="", inspectorName="", startedAt=Date(), status= .inProgress, templateId="" | `items:[ChecklistItem]?`, `hazards:[Hazard]?` |
| ChecklistItem | id, inspectionId, templateItemId="", title="", category="", result= .unchecked, sortOrder=0 | — |
| Hazard | id, siteId, location="", type= .general, riskLevel= .low, hazardDescription="", correctiveActionStatus= .notStarted, createdAt=Date(), updatedAt=Date() | — (photoPath→photoData) |
- init은 그대로 실제 값 할당 → 선언부에 `= 기본값`만 추가하는 게 대부분. 관계 optional화가 진짜 ripple(접근부 `?? []`).
- WO-2 모델(RiskAssessment/Item)은 이미 호환 — 손대지 마라.

### 주의 (CloudKit 함정)
- private DB는 **기기 iCloud 로그인 필수** — 시뮬레이터도 Settings에서 iCloud 로그인 후 테스트.
- 모든 관계 optional + **inverse 관계 권장**. `.unique` 불가(이미 없음).
- 사진을 externalStorage Data로 옮기면 PhotoStorageService(파일 저장)→Data 반환으로 역할 변경 + 표시부(썸네일 로딩) 전부 갱신 필요. **이게 광범위하면 멈추고 "사진=WO-3b 분리" 제안**(중단조건).

### 완료 조건 (증거 필수)
- [ ] 엔타이틀먼트에 컨테이너+background modes / 앱 빌드 green
- [ ] v1 모델 5종 + 신규 모델 전부 CloudKit 호환(기본값·관계 optional·`.unique` 0)
- [ ] 사진이 externalStorage Data로 저장·표시, 기존 파일 사진 마이그레이션 동작
- [ ] ModelContainer CloudKit-backed
- [ ] VersionedSchema 마이그레이션 무손실(기존 로컬 데이터 보존) + `SWIFTDATA_MIGRATION.md` 갱신
- [ ] **2-시뮬 동기화**: A에서 점검+위험요인(사진 포함)+위험성평가 생성 → B에 출현 (양 기기 스크린샷)
- [ ] **오프라인 단독 완결 유지**: 비행기모드로 점검 시작·완료 가능(스크린샷/설명)
- [ ] 기존 55테스트 회귀 0, 앱 빌드 green
- [ ] `/swiftui-build-qa` · `/safetywalk-qa-guardrails` 통과
- [ ] 보고: 엔타이틀먼트·retrofit 목록·사진 전환·마이그레이션·2기기 동기화 증거

### 중단 조건
- Phase A에서 Apple 계정/결제 벽 → 오너 요청
- 마이그레이션이 기존 데이터 파손 위험 → 멈추고 보고(절대 강행 금지)
- CloudKit 스키마 푸시/동기화 에러로 막힘
- 사진 Data 전환이 너무 광범위 → 멈추고 **WO-3b 분리** 제안

### 검증 / 진행
빌드·테스트(WO-1/2와 동일, 스킴 `-list` 캡처) + **2-시뮬레이터 같은 iCloud 로그인** 동기화. (선택: CloudKit Dashboard에서 레코드 확인.)
**main에서 새 브랜치 `wo3-cloudkit`**. WO-1 handoff 형식 + **2기기 동기화 스크린샷**으로 보고 → 플래너 검수.

**WO-3 결과: ✅ 코드 완료 (실행자 수행 + 플래너 검수 통과, 2026-07-07)**
- 브랜치 `wo3-cloudkit` → main 머지. **Phase A**(프로비저닝, 플래너): 고유 번들ID `com.gwonbyeonghag.safetywalk`(+.mac) · 컨테이너 `iCloud.com.gwonbyeonghag.safetywalk` · 커밋 `d2ccda1`. **Phase B**(코드, 실행자): `daf0a2b`.
- v1 모델 5종 CloudKit 호환(기본값·관계 optional) · **사진 `photoData`(externalStorage Data)** 전환 + VersionedSchema V1→V2 마이그레이션(파일사진→Data, 원본삭제) · 양 앱 CloudKit ModelContainer(동일 컨테이너) · 관계 call-site ~30 + 사진 6곳 리플.
- **⚠️ 문서에 없던 CloudKit 제약 발견·수정**: 모든 관계에 **inverse 필수**(없으면 런타임 fatalError). Area.site·ChecklistItem.inspection·Hazard.inspection·RiskAssessmentItem.riskAssessment 추가. **3개 문서에 제약 명시**(다음 스키마 변경 대비).
- **플래너 독립 검증**: 코어 `swift test` **40/40**(신규 마이그레이션 correctness 테스트 — 실디스크 V1→V2·사진 바이트 보존·원본삭제) · inverse 4쌍·컨테이너 양앱 일치·externalStorage·`.unique` 0(주석뿐) 확인 · **iOS+macOS 컴파일 green** · CloudKit 컨테이너 iOS시뮬+macOS(Debug/Release) 실행 무크래시.
- **🔴 남은 확인(오너, 실기기)**: 실제 iPhone↔Mac 2기기 동기화(이 환경엔 기기·iCloud 없어 불가). `xcodebuild test`도 이 환경 러너-attach 한계로 실행 불가(컴파일은 항상 성공). → 오너가 실기기로 최종 확인.
- 부수: 기존 `~/Library/Application Support/default.store`(7/1, 스키마 불일치)는 백업만(삭제 X) — 오너 판단.
→ **CloudKit 코드 완성. v2 기능 전부 완성** (실기기 동기화 확인 후 App Store 동시제출 WO-6).

---

## WO-5 — iOS 디자인 폴리시 (DESIGN_DIRECTION 적용) ✅ DONE (검수 통과 2026-06-27)

> **신규 기능 아님 = 시각 폴리시.** `DESIGN_DIRECTION.md`를 기존 iOS 화면에 입혀 **시각 언어를 확립**한다.
> 방법은 위키 `frontend-design-agent-workflow`의 Bundled Polish + Visual QA. **Apple 계정 무관 → 대기 중 진행.**
> 리포트는 다음 WO(언어 확립 후 재사용). 성공기준은 "동작 중립 + 시각 일관" (WO-1 추출과 같은 결).

### 배경 / 목적
`DESIGN_DIRECTION.md`에서 정체성 확정: **신뢰·명료·현장감 / 시그니처 = 위험등급 컬러 시스템 / navy+orange 쿨·웜 분리 / Apple HIG liquid-glass**. 이제 기존 iOS 화면에 이 언어를 **일관 적용**한다. 이 언어가 이후 macOS(WO-4)·리포트의 토대.

### 목표 (verifiable)
기존 iOS 화면이 `DESIGN_DIRECTION.md`를 따른다: 위험등급 칩 시스템 일관, 쿨/웜 팔레트 분리, SF Pro + **monospaced 숫자**, liquid-glass 위험 칩, dense-calm. **동작 변화 0(시각만). 기존 64테스트 회귀 0.**

### 스코프
**✅ 포함:**
- **재사용 위험 칩/레일 컴포넌트**(SwiftUI) 생성 → 위험 표시 전부 통일(홈 위험 레일·위험요인 배지·위험성평가 밴드·빈도×강도 점수 칩). 반투명 liquid-glass 머티리얼. **← 시그니처.**
- **팔레트 쿨/웜 분리**: 인터랙티브 **액센트 = navy/blue**(현재 `AccentColor.colorset` 확인 후 쿨로 교체). **오렌지는 위험-보통 의미 전용**, green=완료 전용. ⚠️ 앱 전역 영향 → 라이트/다크 스샷으로 확인.
- **타이포**: SF Pro 역할(display/body/utility) + **숫자 monospaced digits**(위험점수·홈 카운트·날짜 정렬).
- HIG liquid-glass 머티리얼을 위험 칩(필요시 카드)에 일관 적용.
- `DESIGN_DIRECTION.md` §3 **템플릿 미감 기본값 제거**(불필요 gradient/orb, 의미 없는 마커 등).
- (가벼움) UI 문구 **명백한 위반만** 수정(§5) — 전면 재작성 아님.
- **`design-visual-qa` 루프**: 화면별 렌더→스크린샷→`DESIGN_DIRECTION` §2 자기비판·§3 금지목록으로 비평→다듬기(라이트+다크).

**⛔ 제외:** 리포트(다음 WO — 단 위험 칩은 재사용 가능하게 설계) · macOS(WO-4) · CloudKit(WO-3) · 신규 기능 · 모델/로직 변경 · 문구 전면 재작성.

**🚫 금지:** 모델/로직/**동작 변경**(시각만), 위험색을 장식으로 사용, 시그니처 외 대담 요소 추가(경쟁 금지).

### 대상 화면
`Views/` Home · Inspection · Hazard · History · Settings · Onboarding · RiskAssessment. (Export=리포트 제외.)

### 완료 조건 (증거 필수)
- [ ] 재사용 위험 칩/레일 컴포넌트 + **위험 표시 전부 그걸로 통일**
- [ ] `AccentColor` = 쿨(navy/blue), 오렌지=위험-보통 전용 (앱 전역, 라이트/다크 스샷)
- [ ] 숫자 monospaced(점수·카운트·날짜)
- [ ] 주요 화면 `design-visual-qa` 통과 — **전/후 스샷(라이트+다크)**, `DESIGN_DIRECTION` 일치
- [ ] §3 템플릿 미감 기본값 잔존 0
- [ ] **동작 변화 0**: 모델/로직 무변경, 앱 빌드 green, 기존 64테스트 회귀 0
- [ ] 문구 손댔으면 EN/KO 패리티
- [ ] 보고: 칩 컴포넌트·팔레트 변경·타이포·화면별 전후 스샷

### 중단 조건
- 폴리시가 모델/로직 변경을 요구 / 액센트 변경이 예기치 않게 깨짐 / `design-visual-qa`가 폴리시를 넘어선 구조 재설계를 요구 → 멈추고 보고.

### Skills
`/design-visual-qa`(핵심 — 렌더→스샷→비평 루프) · `/screen-implementation-review` · `/navigation-qa` · `/swiftui-build-qa` · `/safetywalk-qa-guardrails`. 막히면 `/diagnose`, 완료/중단 전 `/handoff`.

### 진행 / 보고
**main에서 새 브랜치 `wo5-ios-design-polish`.** WO-1 handoff 형식 + **화면별 전후 스크린샷(라이트/다크)**으로 보고 → 플래너 검수.

**WO-5 결과: ✅ 완료 (실행자 수행 + 플래너 검수 통과, 2026-06-27)**
- 브랜치 `wo5-ios-design-polish` → main 머지: `381e7dc` 폴리시(시각만), `122bfb8` 스샷 투어 테스트
- **시그니처**: `Views/Components/RiskIndicator.swift` — `RiskChip`(`.ultraThinMaterial` liquid-glass + 위험색 틴트 + dot/라벨), `RiskDot`(레일/분포). 위험 표시 전부 통일, 흩어진 `riskColor()/riskLabel()` 6벌 → 단일 소스.
- **팔레트**: `AccentColor` navy(라이트)/blue(다크). in-progress 배지 orange→blue, RA 아이콘/버튼 쿨. **오렌지=위험-보통 전용**, green=완료 전용.
- 타이포: monospaced 숫자(카운트·진행·점수).
- **플래너 독립 검증**: SafetyWalkCore **0 변경(코어 무오염)** · 모델 0 · HomeViewModel은 색만(`.orange→.blue`) · 앱 **BUILD SUCCEEDED** · 테스트 64 회귀 0. **스크린샷 직접 확인**: 홈(다크) navy 액센트·green 안정·dense-calm / RA 상세(라이트) liquid-glass 위험칩(골드·주황·빨강)·면책·monospaced → `DESIGN_DIRECTION` 일치.
- 잔여(경미, 수용): 개별 전/후 풀캡처는 홈·온보딩·RA 중심. Hazard/Inspection/History/Settings는 전역 팔레트+통일 컴포넌트가 적용되나 개별 스샷 미캡처 — 투어 테스트로 확장 가능.
→ **iOS 시각 언어(위험칩 시스템·쿨/웜·HIG liquid-glass) 확립.** macOS(WO-4)·리포트의 토대.

---

## WO-5b — 리포트: 풀 A4/Letter 멀티페이지 엔진 + 위험성평가표·JHA ✅ DONE (검수 통과 2026-06-27)

> **공식 제출 문서**를 제대로 만든다. 현재 `ImageRenderer` 단일 긴 페이지로는 페이지 분할 불가(행 잘림) →
> **페이지네이션 엔진을 새로 만드는 엔지니어링 WO**(폴리시 아님). **Apple 계정 무관 → 지금 진행.**
> WO-5에서 확립한 위험색 언어를 **인쇄용(solid 밴드)** 으로 재사용. `DESIGN_DIRECTION.md` §7 기준.

### 배경 / 목적
위험성평가표·JHA는 출력·제출하는 **공식 문서**다. 현재 점검 리포트는 단일 긴 PDF(기존 `InspectionExportService` TODO도 멀티페이지 미구현 인정). 제대로 된 **A4(KR)/Letter(US) 멀티페이지** 엔진을 만들고, 그 위에 리포트 3종을 얹는다. 엔진은 **크로스플랫폼**으로 만들어 macOS(WO-4)가 재사용한다.

### 목표 (verifiable)
**크로스플랫폼 멀티페이지 PDF 엔진**(SwiftUI 페이지 배열) + **위험성평가표(KR A4)·JHA 워크시트(US Letter)** 생성 + **기존 점검 리포트 이관**. 행이 많으면 **여러 페이지로 분할**(행을 페이지 경계서 자르지 않음), 반복 머리말 + 페이지번호 n/k. **데이터/모델 변경 0(리포트는 읽기 전용 출력). 기존 64테스트 회귀 0.**

### 핵심 기술 방향 (크로스플랫폼 = WO-4 재사용의 근거)
- **렌더**: `ImageRenderer`(SwiftUI, iOS16+/macOS13+ 공통) + **Core Graphics PDF 컨텍스트**(`CGContext`+`CGDataConsumer`/`beginPDFPage` — CG라 iOS·macOS 공통). **`UIGraphicsPDFRenderer`(UIKit 전용) 쓰지 말 것** — 그러면 macOS에서 다시 만들어야 함.
- **페이지네이션**: 리포트 = 반복 머리말 + 본문 **블록 배열**(표 행/섹션) + 반복 푸터(page n/k). 블록을 페이지 가용 높이에 맞게 **청킹**해 `[페이지뷰]` 생성 → 각 페이지뷰를 PDF 페이지로 렌더. 표 행 높이는 **보수적으로 추정**(여유 두고, 행을 페이지 넘겨 자르지 않음). 우리 리포트는 **표 중심**이라 자유흐름 텍스트 분할 같은 난케이스 아님.
- **인쇄용 디자인**(DESIGN_DIRECTION §7): liquid-glass(반투명) 대신 **solid 위험색 밴드/칩**(인쇄 가독), **navy 마스트헤드**, **monospaced 숫자**, 흰 배경, SF Pro, **면책 고지(법적·필수)**.
- 위치: iOS 앱 `Views/Reports/`(또는 `Reporting/`)에 자기완결로, **SwiftUI+CG라 WO-4서 추출/재사용 가능**하게. (지금 공유 UI 패키지 추출은 스코프 밖 — 깔끔히만 둔다.)

### 스코프
**✅ 포함 (단계화):**
- **① 페이지네이션 엔진** — 블록 배열 → A4/Letter 멀티페이지 PDF, 반복 머리말/푸터, page n/k, 행 비절단.
- **② 위험성평가표 (KR, A4)** — 헤더(현장·평가일·평가자·기법·종류) + 항목 표(공정/작업·유해위험요인·현재조치·**위험성 solid 밴드**[빈도×강도 점수+밴드 / 3단계]·감소대책·개선후·담당/기한·상태) + 면책. 한국어.
- **③ JHA 워크시트 (US, Letter)** — 헤더 + **순서 있는 작업단계**(step#·task·hazards·controls·risk) + 면책. 영문/OSHA 라벨.
- **④ 기존 점검 리포트 이관** — 이 엔진으로(카테고리별 항목·결과·사진·노트 + 위험요인 + 면책). 멀티페이지·사진 포함.
- 공유(ShareSheet) 연결(기존 재사용). 신규 문자열 EN/KO 패리티.

**⛔ 제외:** macOS 앱(WO-4 — 단 엔진 재사용 가능하게) · CloudKit(WO-3) · 신규 기능 · **데이터/모델 변경**(리포트는 읽기전용) · 앱 화면 디자인(WO-5에서 끝).

**🚫 금지:** 모델/로직 변경, 위험색을 의미 없이 사용, 면책 고지 누락(법적), `UIGraphicsPDFRenderer`로 iOS 전용 구현.

### 완료 조건 (증거 필수)
- [ ] 엔진: 블록 배열 → **멀티페이지** PDF(A4+Letter), 반복 머리말 + 푸터 page n/k, **행 페이지경계 비절단**, CG PDF(크로스플랫폼, UIKit 전용 API 미사용)
- [ ] 위험성평가표(KR A4)·JHA(US Letter) 정상 렌더, **행 많으면 ≥2페이지로 분할**(PDF 증거)
- [ ] 점검 리포트 이 엔진으로 이관(멀티페이지, 사진 포함)
- [ ] 인쇄용: solid 위험색 밴드 · navy 마스트헤드 · monospaced 숫자 · **모든 리포트에 면책 고지**
- [ ] 공유/Export 동작 / 신규 문자열 EN/KO 패리티
- [ ] **데이터·모델 변경 0**, 앱 빌드 green, 기존 64테스트 회귀 0
- [ ] `design-visual-qa`(리포트 렌더→검토→§7 비평) · `safetywalk-qa-guardrails`(면책·스코프) 통과
- [ ] 보고: 엔진 방식 · 리포트 3종 · **≥2페이지 PDF 증거(각 타입)** · 빌드/테스트

### 중단 조건
- 행 높이 추정이 불안정해 행이 잘리거나 넘침 → 멈추고 보고(HTML/CSS 대안 검토)
- CG PDF 크로스플랫폼 경로가 API 벽 → 보고
- 사진 많은 점검 리포트 분할이 과도하게 복잡 → **④ 점검 리포트 이관을 분리**(위험성평가표·JHA 먼저, 점검은 단일페이지 fallback 유지) 후 보고

### Skills
`/design-visual-qa`(리포트는 시각 산출물 — 렌더→PDF 확인→§7 비평) · `/swiftui-build-qa` · `/safetywalk-qa-guardrails` · `/screen-implementation-review`. 막히면 `/diagnose`, 완료/중단 전 `/handoff`.

### 진행 / 보고
**main에서 새 브랜치 `wo5b-reports`.** 단계(①→②→③→④)별로 진전, 각 단계 검증. WO-1 handoff 형식 + **≥2페이지 PDF 증거(각 리포트)** 로 보고 → 플래너 검수.

**WO-5b 결과: ✅ 완료 (실행자 수행 + 플래너 검수 통과, 2026-06-27)**
- 브랜치 `wo5b-reports` → main 머지: `6ebfe4f` 엔진+리포트, `732ee4c` 테스트
- **엔진**(`Views/Reports/ReportEngine`+`ReportComponents`): `ImageRenderer` + **Core Graphics PDF**(`CGDataConsumer/CGContext/beginPDFPage`, **UIKit 0**) → 크로스플랫폼, WO-4 재사용. 블록 **실측 높이**(추정 아님)로 청킹 → 행 비절단. 반복 navy 마스트헤드 + 컬럼헤더 + page n/k.
- **리포트 3종**: 위험성평가표(KR A4, 28행→2p) · JHA(US Letter, 22단계→3p) · 점검(A4, 사진 →5p). 구 `InspectionReportView`(647줄) 제거, `exportPDF`가 엔진 사용.
- 인쇄용(§7): solid 위험색 밴드 · navy 마스트헤드 · monospaced 숫자 · 흰 배경 · 모든 리포트 면책.
- **플래너 독립 검증**: SafetyWalkCore 0 · 모델 0 · 엔진 UIKit 0(`CGContext` PDF 확인) · 앱 **BUILD SUCCEEDED** · 테스트 64+3 회귀 0. **PDF 직접 확인**: 위험성평가표 2p — navy 마스트헤드·반복 컬럼헤더·solid 위험밴드(점수)·monospaced·p2 면책 → `DESIGN_DIRECTION` §7 일치.
→ **풀 멀티페이지 리포트 엔진(크로스플랫폼) 확립.** macOS(WO-4)가 그대로 재사용.

---

## WO-4 — 네이티브 macOS 앱 (셸: 대시보드 + 리포트, 시드 데이터) ✅ DONE (검수 통과 2026-06-27)

> D-1: **네이티브 macOS 별도 앱**(매니저 대시보드/리포트 허브). SafetyWalkCore + WO-5b 리포트 엔진 재사용.
> **계정 무관 부분 먼저**: 타깃·대시보드·리포트를 **로컬/시드 데이터**로. WO-3(CloudKit)가 나중에 동기화만 연결.
> ⚠️ 기기 간 동기화 검증은 WO-3까지 불가 — 시드로 UI·기능만 검증.

### 배경 / 목적
iOS는 현장 도구(대시보드 금지). **macOS = 매니저 대시보드 + 리포트 허브**(V2_ROADMAP AD-4). 아이폰이 기록한 데이터를 매니저가 Mac에서 조망·출력. 데이터 공유는 WO-3(CloudKit) 담당이나, **UI·리포트는 계정 없이 지금** 만든다(시드). WO-5 시각 언어 + WO-5b 리포트 엔진 재사용.

### 목표 (verifiable)
repo에 **네이티브 macOS 앱 타깃** 추가(SafetyWalkCore 의존), **대시보드 + 브라우즈 + 리포트 허브**가 시드 데이터로 동작. macOS 앱 빌드·실행, 대시보드 렌더, 리포트 생성/미리보기/PDF. **iOS 앱·SafetyWalkCore 무변경(추가만). 기존 64테스트 회귀 0.**

### 스코프
**✅ 포함 (단계화):**
- **① macOS 앱 타깃** — 같은 repo/프로젝트에 별도 앱 product, SafetyWalkCore 의존. 번들 예 `com.safetywalk.macos`(iCloud 컨테이너는 WO-3에서 iOS와 공유 — 번들ID와 무관). **`#if DEBUG` 시드 데이터**(샘플 사이트/점검/위험요인/위험성평가) — 대시보드/리포트 개발·검증용.
- **② 대시보드**(조망, AD-4 + DESIGN_DIRECTION): 사이트별 위험요인 **위험등급 분포(위험칩 언어)** · 미완료 시정조치 · 위험성평가 due(연1회) · 최근 점검. calm-dense, **macOS HIG**, navy/cool 액센트.
- **③ 브라우즈**: 사이트·점검·위험요인·위험성평가 목록/상세(**읽기 중심**). `NavigationSplitView`(사이드바 + 디테일).
- **④ 리포트 허브**: **WO-5b 엔진 재사용** — 위험성평가표·JHA·점검 리포트 **생성·미리보기·인쇄·PDF export**(큰 화면). 엔진은 크로스플랫폼(CG PDF)이라 재사용; **사진 로딩만 `#if os(macOS)` NSImage** 분기.
- 현지화 KO/EN(신규 문자열 패리티).

**⛔ 제외:** **CloudKit 동기화(WO-3)** — 단 `ModelContainer`는 WO-3가 CloudKit로 바꿀 수 있게 둔다 · **iOS 앱 변경** · 신규 기능/모델 · **macOS에서 현장 기록(점검/위험요인 생성)** 은 이 셸 밖(뷰+리포트 우선, 편집은 후속 WO).

**🚫 금지:** SafetyWalkCore/iOS/모델 변경(macOS는 **추가만**), 위험색 장식 사용, 시드 데이터를 **릴리스 빌드에 포함**.

### 리포트 엔진 재사용 (주의)
- 엔진·RA表·JHA는 SwiftUI+CoreGraphics라 크로스플랫폼 → macOS 타깃에 **파일 공유(타깃 멤버십 추가)** 또는 가벼운 `Shared/` 이동으로 재사용. 점검 리포트 사진(UIImage)만 `#if os(macOS)` NSImage.
- 공유가 **광범위 추출(공유 UI 패키지)** 을 요구하면 → **멈추고 보고**: 리포트를 별도 후속 WO로 분리하고 **대시보드·브라우즈 먼저** 마무리.

### 완료 조건 (증거 필수)
- [ ] macOS 앱 타깃 빌드·실행(SafetyWalkCore 의존), **시드 데이터로 대시보드 렌더**
- [ ] 대시보드: 위험등급 분포 · 미조치 · RA due · 최근 점검(위험칩 언어)
- [ ] 브라우즈: 사이트/점검/위험요인/위험성평가 목록·상세
- [ ] 리포트 허브: 3종 생성·미리보기·PDF export(엔진 재사용)
- [ ] macOS HIG · navy/cool 액센트 · `DESIGN_DIRECTION` 일치(스샷 라이트+다크)
- [ ] **iOS 앱·SafetyWalkCore 무변경**(`git diff`로 확인 — macOS는 추가만), iOS 빌드·기존 64테스트 회귀 0
- [ ] 시드 데이터 `#if DEBUG`(릴리스 미포함), 신규 문자열 EN/KO 패리티
- [ ] 보고: 타깃 구성 · 대시보드 · 브라우즈 · 리포트 · 시드 방식 · macOS 스샷

### 중단 조건
- 리포트 엔진 공유가 광범위 추출 필요 → 멈추고 분리 제안 · macOS SwiftData/`NavigationSplitView` 벽 · 모델 변경 필요 · `ModelContainer` 설계가 WO-3 CloudKit와 상충 → 보고.

### Skills
`/design-visual-qa`(대시보드·리포트 macOS 렌더→스샷→§2/§3·§7 비평) · `/screen-implementation-review` · `/swiftui-build-qa` · `/safetywalk-qa-guardrails`. 막히면 `/diagnose`, 완료/중단 전 `/handoff`.

### 진행 / 보고
**main에서 새 브랜치 `wo4-macos-shell`.** 단계(①→②→③→④)별 진전, 각 검증. WO-1 handoff 형식 + **macOS 스샷(대시보드·리포트, 라이트/다크)** + **iOS 무변경 증거**로 보고 → 플래너 검수.

**WO-4 결과: ✅ 완료 (실행자 수행 + 플래너 검수 통과, 2026-06-27)**
- 브랜치 `wo4-macos-shell` → main 머지: `c2a7b49` 크로스플랫폼 사진타입+macOS 키, `108a818` macOS 셸. 20파일 +1831/−7.
- **macOS 타깃 `SafetyWalkMac`**(`com.safetywalk.macos`, macOS 14, SafetyWalkCore 의존, 같은 프로젝트 추가만). `MacModelContainer` = **WO-3 CloudKit 단일 스왑 지점**(`#if DEBUG` 인메모리 시드).
- **대시보드**(통계타일·현장별 위험분포·미조치·RA due·최근점검, 위험칩 언어) / **브라우즈**(NavigationSplitView, 읽기전용 현장·점검·위험요인·위험성평가) / **리포트 허브**(엔진 재사용, PDFKit 미리보기·NSSavePanel·NSPrintOperation).
- 엔진 재사용 = **타깃 멤버십 공유(추출 아님, STOP 올바르게 회피)**. 사진만 `PlatformImage`(`#if canImport`) — iOS 경로 byte-동일.
- **플래너 독립 검증**: SafetyWalkCore 소스 **0** · iOS는 사진가드+키만(로직 0) · 시드 `#if DEBUG` · EN/KO +30/+30 · **macOS BUILD SUCCEEDED · iOS BUILD SUCCEEDED · 코어 39/39, 회귀 0**. **스샷 직접 확인**: 관리 대시보드(라이트+다크) — 위험색 도트+monospaced 분포·미조치 위험칩·RA "기한 초과" 배지·navy 액센트·HIG. 리포트 PDF 3종(RA 2p·JHA 2p·점검 3p NSImage).
→ **네이티브 macOS 매니저 셸 완성**(iOS 디자인 언어 + 리포트 엔진 재사용). WO-3가 컨테이너만 CloudKit로 스왑하면 iPhone↔Mac 동기화.

---

## WO-7 — iPad 레이아웃 폴리시 (iOS 앱 iPad-네이티브화) ✅ 완료·머지 (2026-07-07)

> iOS 앱은 **이미 유니버설(`TARGETED_DEVICE_FAMILY = 1,2`)** — iPad에서 돌지만 **iPhone 레이아웃이 커진 모양**. iPad-네이티브 경험으로.
> **동작·모델·동기화 무변경 = 시각/네비 폴리시.** iPhone·macOS는 손대지 않는다. 계정 무관 → 언제든 진행.
> DESIGN_DIRECTION 언어(위험칩·쿨/웜·HIG) 그대로. 방법은 WO-5와 동일(design-visual-qa 루프).

### 🎨 디자인 타겟 (오너 승인 2026-07-07 — "이대로")
**목업 = `docs/design/ipad-home-mockup.html`** · 아티팩트: https://claude.ai/code/artifact/c8270787-0626-455f-9bc9-1be98afbc7bd (라이트/다크)
- **레이아웃**: iPad 가로(regular) = `NavigationSplitView`(사이드바 ~264pt + 콘텐츠 디테일). 사이드바 = 앱 아이덴티티 헤더(방패+"현장 안전 지킴이"+역할) + 섹션 리스트(홈·점검·위험요인·기록·위험성평가·설정, **navy 선택 틴트**).
- **홈 디테일 = 2단 그리드**(iPhone 세로 한 줄 → iPad는 좌우로): **좌** = "미조치 위험요인"(위험 rail: 높음/보통/낮음 카운트) + "빠른 작업"(점검 시작 = primary navy 버튼 · 위험요인 추가 = secondary); **우** = "최근 점검" 리스트 + "위험성평가 기한".
- **디자인 토큰**: macOS 폴리시와 **동일 팔레트**(쿨 뉴트럴 + navy 액센트 어댑티브, 위험칩, 카드 r14·소프트섀도우, tabular 숫자) — DESIGN_DIRECTION 한 언어. **단 구현은 iOS 디자인 자산 재사용**(`RiskChip` 등 WO-5 산출물). ⚠️ **`MacDesign.swift`는 macOS 전용 → import 금지**; iPad는 iOS/공유 레이어 토큰만. 공유가 필요하면 공유 레이어에 두되 중복 토큰 신설은 피한다.
- **adaptive**: iPad regular = 사이드바 / iPhone·compact(세로 포함) = **기존 탭바+스택 그대로**(무회귀).
- **원칙**: 홈은 **현장 도구**(대시보드 아님 — 조망 대시보드는 macOS 담당). iPad는 그 홈을 **넓게** 펼칠 뿐.

### 배경 / 목적
CONTEXT/PRD의 v1 "iPad 전용 레이아웃 없음" 제약을 v2에서 해제. iPad는 현장 감독이 큰 화면으로 쓰는 기기 → **iPad에선 `NavigationSplitView`(사이드바+디테일) 등 iPad-HIG 네비**로, iPhone(compact)은 기존 탭/스택 유지. 기존 iOS 콘텐츠 뷰를 **재사용**(재작성 X).

### 목표 (verifiable)
iPad(regular size class)에서 **iPad-네이티브 네비게이션 + 큰 캔버스 활용**. **iPhone(compact)·macOS 무변경, 모델/로직/동기화 변경 0, 기존 테스트 회귀 0.**

### 스코프
**✅ 포함:**
- **`horizontalSizeClass` 적응**: iPad regular → `NavigationSplitView`(사이드바 = 홈/점검/위험요인/기록/위험성평가/설정 섹션, 디테일 = 콘텐츠). iPhone compact → **기존 탭바+스택 그대로**.
- 기존 iOS 콘텐츠 뷰(체크리스트·위험요인·위험성평가·기록·설정) **재사용** — iPad shell만 추가.
- 폼·리스트가 iPad 넓은 화면에서 자연스럽게(readable width·과도한 빈 공간 없이·다단 가능한 곳은 다단).
- **위험칩 언어·타이포·팔레트 그대로**(DESIGN_DIRECTION). `design-visual-qa`(iPad 라이트+다크).

**⛔ 제외:** iPhone 레이아웃 변경 · macOS 변경 · CloudKit/모델/로직/신규기능. **iPad 전용 대시보드(Mac식 조망)**는 이번 범위 밖(기본 = 적응형 필드도구; 원하면 후속 WO).

**🚫 금지:** 모델/동작 변경, iPhone 회귀, 위험색 장식 사용.

### 완료 조건 (증거 필수)
- [ ] iPad(시뮬)에서 `NavigationSplitView` 네이티브 렌더, 전 화면 접근 가능
- [ ] **iPhone 무회귀**(compact = 기존 탭/스택 그대로, 스샷 비교)
- [ ] iPad 라이트+다크 `design-visual-qa` 통과(DESIGN_DIRECTION 일치·큰 화면 자연스러움)
- [ ] **동작/모델/동기화 변경 0**: 앱 빌드 green, 기존 테스트 회귀 0, macOS 무변경
- [ ] 보고: iPad 셸 구조·재사용한 뷰·iPad/iPhone 스샷(라이트·다크)

### 중단 조건
- split view가 특정 화면의 **재설계**를 요구 / 모델·로직 변경 필요 / iPhone compact가 깨짐 → 멈추고 보고.

### Skills
`/design-visual-qa`(iPad 렌더→스샷→비평) · `/navigation-qa`(적응형 네비 전환) · `/screen-implementation-review` · `/swiftui-build-qa` · `/safetywalk-qa-guardrails`.

### 진행 / 보고
**main에서 새 브랜치 `wo7-ipad-layout`.** WO-1 handoff 형식 + **iPad·iPhone 스샷(라이트/다크)** 으로 보고 → 플래너 검수. (선행: 오너 실기기 3기기 동기화 확인 후 착수 권장 — 단 코드상 의존은 없음.)

**WO-7 결과:**
- 상태: ✅ 완료·main FF 머지 (2026-07-07)
- 요약: iPad(regular)에 `NavigationSplitView` 네이티브 셸(사이드바 6섹션 + 아이덴티티 헤더, navy 선택) + 홈 2단(좌 rail·빠른작업[점검시작/위험요인등록] / 우 최근점검·위험성평가 기한). iPhone·compact는 **idiom 게이트**(`idiom==.pad && hSize==.regular`)로 기존 TabView 그대로 = 무회귀. 홈 due 카드는 공유 순수함수 `RiskAssessment.dueStatus`(365+30, macOS DueBadge와 패리티) 신설·TDD 레드퍼스트. 기존 6뷰 재사용(재작성 0), `MacDesign` 미import.
- 플래너 재검증(러버스탬프 X): **Core 49/49**(due 9 신규·회귀 0) · **iOS 빌드 green** · **macOS 빌드 green**(Core additive 무손상) · **git diff SafetyWalkMac 0건** · **MacDesign 미참조** · iPad 라이트/다크 + iPhone 무회귀 스샷 3종 목업 대조 일치. 검수 중 발견한 due 카드 빈-상태 문구 오용(`homeNoOpenHazards` 재사용)은 플래너가 전용 키 `homeNoDueAssessments`로 인라인 수정 후 재빌드 green.
- 후속 ✅ 완료(2026-07-07, `wo7b-mac-due-converge`): macOS `DashboardView.DueBadge`의 인라인 365/30 규칙을 제거하고 공유 `RiskAssessment.dueStatus`로 수렴(iOS와 동일 패턴). behavior-neutral(패리티 테스트 보장) · macOS 빌드 green · diff 1파일(+5/−10). → **due 규칙 단일 진실원천 확립(iOS·macOS 공용).**
- 증거 위치: 브랜치 `wo7-ipad-layout`(→main FF), 스샷 `wo7-shots/`(ipad_home_light/dark_landscape_win · iphone_home_light/dark), 아티팩트 ef123a9e. 커밋 216da63(실행자) + b061526(플래너 문구 수정).

---

## WO-8 — macOS 디자인 폴리시 (세련된 네이티브) ✅ DONE (검수 통과 2026-07-07)

> **✅ 디자인 타겟 (오너 승인 2026-07-07): `docs/design/macos-dashboard-mockup.html`** — 이 목업이 대시보드의 **정확한 타겟**이다. 실행자는 이 HTML의 CSS `:root` **디자인 토큰(색·여백·라운딩·타이포)을 SwiftUI로 옮긴다.** 브라우저로 열어 라이트/다크 둘 다 확인.
> **요약 토큰:** 뉴트럴(쿨) — light `bg #F4F6F9`/`surface #FFF`/`sidebar #EEF1F6`/`border #E3E7EE`/`ink #1A1E26`/`muted #727B8C`, dark `#15181E`/`#1D2027`/`#191C22`/`#2B303A`/`#E9ECF2`/`#8B93A2`. 액센트(쿨) `#2360C9`(L)/`#5C9BF5`(D). 위험램프(의미 전용) 낮음 `#A9790A`/`#D2A63C`·보통 `#DA761A`/`#EE9040`·높음 `#CF3F3F`/`#E4615C`·안정 green `#2C9A57`/`#40B673`. 카드 라운딩 12(sm 8)·그림자 은은(`0 1px 2px`+`0 4px 16px`)·**SF Pro(system)**·숫자 `tabular-nums`·위험칩=색 pill+dot·**8pt 간격**. **대시보드가 타겟이고 브라우즈·리포트허브도 같은 토큰·카드 스타일로 통일.**

> WO-4는 기능 "셸"이라 디자인 폴리시 패스를 못 받음(iOS는 WO-5에서 받음). 이번에 macOS를 다듬는다.
> **오너 결정(2026-07-07): 방향 = 세련된 네이티브** — Apple HIG 유지 + premium 대시보드(Linear/Stripe/Vercel 감성)의 **여백·정돈·깊이**를 흡수. **커스텀 웹룩으로는 가지 않음.**
> 방법 = 위키 frontend-design "Bundled Polish + Visual QA". **시각만 = 동작/모델/동기화 무변경.** DESIGN_DIRECTION 언어 그대로.

### 배경 / 목적
현재 macOS 앱은 기능은 완비됐으나 밋밋(셸 상태). premium 대시보드의 **정돈감**을 네이티브 방식으로 흡수해 "진짜 맥 앱인데 이쁜" 수준으로. (오너가 "Mac UI가 좀 아쉽다"고 피드백 → 이 WO로 해소.)

### 목표 (verifiable)
macOS 앱(대시보드·브라우즈·리포트허브)이 **세련된 네이티브**로 폴리시됨. **iOS·iPad·코어·동기화 무변경, 모델/로직/동작 변경 0, 기존 테스트 회귀 0.**

### "세련된 네이티브"가 흡수할 원칙 (레퍼런스에서 원칙만 — 웹룩 복붙 아님)
- **넉넉한 여백** — 8pt 그리드 일관 간격, 섹션·카드 사이 숨 쉴 공간
- **타이포 스케일** — 명확한 위계(섹션 타이틀 > 카드 타이틀 > 라벨), SF Pro 웨이트/크기 일관, **숫자 monospaced**
- **정돈된 카드/컨테이너** — 일관 corner radius + hairline border 또는 soft shadow, 그룹 배경
- **미묘한 깊이** — 네이티브 머티리얼(`.regularMaterial` 등), 위험칩은 살짝 elevated
- **사이드바 정돈** — `NavigationSplitView` 사이드바(섹션 헤더·아이콘·선택상태) HIG 다듬기
- **상태/메타 일관** — pill·secondary text 색·정렬
- **절제** — 대담함은 시그니처(위험등급 컬러칩)에만, 나머지 조용히
- ❌ 비네이티브 폰트(Inter 등)·과한 그라디언트/장식·기능 추가·데이터 변경.

### 스코프
**✅ 포함:** macOS(`SafetyWalkMac`) **대시보드·브라우즈**(사이트/점검/위험요인/위험성평가)·**리포트 허브** UI 폴리시. 재사용 컴포넌트(카드/섹션/스탯타일) 정돈. DESIGN_DIRECTION 언어 유지(필요시 **macOS 폴리시 토큰**을 DESIGN_DIRECTION에 추가). `design-visual-qa` 루프(라이트+다크).
**⛔ 제외:** iOS·iPad 변경 · 코어/모델/로직/동기화 변경 · 신규 기능 · **리포트 PDF 레이아웃**(WO-5b/§7은 그대로) · 커스텀 웹룩 전환.
**🚫 금지:** 동작/모델 변경, 위험색 장식 사용, 시그니처 외 대담 요소 경쟁.

### 완료 조건 (증거 필수)
- [ ] 대시보드·브라우즈·리포트허브 세련된 네이티브 폴리시 — **전/후 스샷(라이트+다크)**
- [ ] 일관 여백(8pt)·타이포 스케일·카드 스타일·미묘한 깊이 적용
- [ ] `design-visual-qa` 통과(DESIGN_DIRECTION 일치 + "premium 정돈감")
- [ ] **동작/모델/동기화 변경 0**, iOS/iPad 무변경, macOS 빌드 green(Debug+Release), 기존 테스트 회귀 0
- [ ] 보고: 폴리시 항목·컴포넌트·화면별 전후 스샷

### 중단 조건
- 폴리시가 모델/로직/네비게이션 **재설계**를 요구 → 멈추고 보고.

### Skills
`/design-visual-qa`(핵심 — 렌더→스샷→비평) · `/screen-implementation-review` · `/swiftui-build-qa` · `/safetywalk-qa-guardrails`.

### 진행 / 보고
**main에서 새 브랜치 `wo8-macos-polish`.** WO-1 handoff 형식 + **macOS 화면별 전/후 스샷(라이트·다크)** 으로 보고 → 플래너 검수.

**WO-8 결과: ✅ 완료 (실행자 수행 + 플래너 검수 통과, 2026-07-07)**
- 브랜치 `wo8-macos-polish` @ `bb349c2` → main 머지. 전/후 아티팩트: https://claude.ai/code/artifact/0eec2253-503f-4d28-a6cf-c86adf4e9d7f
- 승인 목업 `docs/design/macos-dashboard-mockup.html` CSS 토큰을 `SafetyWalkMac/Support/MacDesign.swift`(신규·macOS 전용)로 이식 — 쿨 뉴트럴 + navy 액센트 어댑티브(라이트/다크, 외형 피커 대응), 8pt·라운딩12/8·소프트섀도우. 대시보드·브라우즈·리포트허브 통일 폴리시(스탯타일·MacCard·사이드바 아이덴티티·헤어라인·tabular).
- **대시보드 밀도(오너 피드백 반영)**: "현장별 위험 분포"를 심각도순 **top 6로 캡**(`riskRowLimit=6`) + **"전체 N개 현장 보기 →"** navy 링크 → 현장 브라우즈. 나머지 6제한 리스트와 일관.
- **플래너 독립 검증**: 변경 전부 `SafetyWalkMac/`(+로컬키 6개만) · **위험칩 시그니처 0 변경** · iOS/코어/모델/동기화/리포트PDF 무변경 · macOS **BUILD SUCCEEDED**(Debug+Release) · 코어 **40/40** · 스샷 목업 일치 · 분포 캡 코드(`Array(sitesBySeverity.prefix(riskRowLimit))` + `if sites.count>limit` 전체보기) 확인. (검수 중 연 `after_dashboard_light.png`은 캡 전 캐시본 — 코드는 캡 확정.)
→ **macOS "세련된 네이티브" 완료.** WO-7 iPad 네이티브 레이아웃 ✅ 완료. 남은 것 = App Store(WO-6).

---

## 부록 A — 사전요건(실행자 환경 가정)

- macOS + Xcode (iOS 17+ / 향후 macOS 14+ SDK)
- 이 repo에 대한 push 권한 (GitHub `safety-walk`)
- CloudKit/Apple 계정 작업은 **WO-3 이전엔 불필요** — WO-0~2는 계정 없이 진행 가능

## 부록 B — 검토 체크리스트 (플래너용)

각 WO 검토 시: ① Acceptance 증거 실재 확인 ② `CLAUDE.md` 규칙 위반 없음(도메인 용어/현지화/스코프)
③ 스키마 변경 시 `SWIFTDATA_MIGRATION.md` 절차 준수 ④ 스코프 크리프 없음 ⑤ iOS 빌드 그린 유지.

---

## WO-9 — macOS 샌드박스 + ModelContainer 폴백 (Release 크래시 수정 + F-1 방어) ✅ 완료·검수 통과·머지 (2026-07-08)

> **증상**: macOS **Release** 앱이 실행 즉시 크래시 — `MacModelContainer.swift:41` `fatalError("Failed to create the macOS ModelContainer: SwiftDataError … migration with an unknown model version")`.
> **근본원인**: 맥앱이 **비샌드박스**(엔타이틀먼트에 `app-sandbox` 없음)라 공용 `~/Library/Application Support/default.store`를 쓰는데, 그 저장소가 **예전 스키마**(플랜의 V1=1.0.0 / V2=2.0.0 어느 것도 아님)라 마이그레이션이 못 알아봄. iOS는 샌드박스(앱 전용 저장소)+clean install이라 안 겪음(실기기 iPhone 첫 실행 정상 확인 = **F-1 iOS는 시뮬 전용**).
> 두 수정이 한 덩어리: ① 맥앱 **샌드박스**(macOS App Store 필수 + 저장소가 앱 전용 컨테이너로 이동 → 공용 store 충돌 소멸) ② **ModelContainer 폴백**(생성 실패 시 fatalError 대신 복구 = F-1 방어, iOS/macOS 공용).

### 목표 (verifiable)
낡은 `default.store`가 남아있는 **이 맥에서 macOS Release 앱이 크래시 없이 대시보드까지 뜬다.** ModelContainer 생성은 정상 상황에서 절대 `fatalError` 안 함 — 실패 시 복구(store 옆으로 치우고 재시도, 최후엔 in-memory)하고 앱은 뜬다. **iOS 무회귀(첫 실행 온보딩 정상·데이터 유지), Core 테스트 green(+신규 복구 테스트), 스키마/모델/마이그레이션 무변경.**

### 스코프
**✅ 포함**
- `SafetyWalkMac.entitlements`: `com.apple.security.app-sandbox = true` + CloudKit용 `com.apple.security.network.client = true` + **리포트 export(NSSavePanel)용 `com.apple.security.files.user-selected.read-write = true`**(플래너 결정 2026-07-07, 실행자 STOP 응답) 추가. 기존 iCloud 컨테이너/CloudKit 엔타이틀먼트 유지.
- **공유 팩토리**를 `SafetyWalkCore`에 신설(가칭 `makeCloudKitContainer`): CloudKit+마이그레이션으로 컨테이너 생성 → 실패 시 **복구**(해당 store 파일 `*.store/-shm/-wal`을 타임스탬프 백업명으로 **이동**[삭제 아님] → fresh 재시도 → 그래도 실패면 최후 in-memory). `SafetyWalkApp.swift`(iOS Release)와 `MacModelContainer.swift`(macOS `#else`) 둘 다 이 팩토리로 교체. macOS `#if DEBUG` in-memory 시드 경로는 그대로.
- **TDD**(Core): 일부러 비호환/손상 store를 temp URL에 만들고 → 팩토리가 **작동하는 컨테이너 반환** + 원본이 **옆으로 이동됨(존재, 삭제 아님)** 을 단언.

**⛔ 제외 / 🚫 금지**
- `~/Library/Application Support/default.store` **삭제·복원 금지**(프로젝트 규칙 — 타 앱 것일 수 있음). 이동은 오직 앱 자신의 지정 store에 한함.
- 스키마/모델/마이그레이션 플랜 변경 금지. iOS를 공유 팩토리로 라우팅하는 것 외 iOS 동작 변경 금지.

**🔴 중단·보고(코딩 전)**
- 샌드박스가 macOS **리포트/PDF export·사진 접근**을 깨면 → NSSavePanel/보안스코프 접근 설계를 **먼저 보고**.
- 복구가 **iOS 기존 로컬 데이터 위치를 바꿔 고아화**할 위험이 있으면(명시 store URL 도입 등) → 데이터 연속성 계획(CloudKit 재싱크 허용?)을 **먼저 보고**.
  → **플래너 결정(2026-07-07): iOS store URL 변경 금지.** 명시 `ModelConfiguration(url:)` 신설 없이 **기본 store URL을 대상**으로 복구(정상 실행 땐 무이동, 실패 시에만 백업 이동→재시도) = 고아화 0. macOS는 샌드박스가 저장소를 컨테이너로 자동 이동.

### 완료 조건 (증거 필수)
- [ ] 낡은 default.store 있는 이 맥에서 **macOS Release 실행 → 크래시 없이 대시보드**(스샷).
- [ ] 샌드박스 후 macOS **리포트/PDF export·브라우즈** 무회귀(확인).
- [ ] 폴백 복구 테스트: 비호환 store 재현 → 앱 뜸 + 원본 **이동됨(삭제 아님)**. Core green(신규 포함).
- [ ] **iOS 빌드 green + 첫 실행(온보딩) 정상 + 무회귀**.
- [ ] 원본 `~/Library/Application Support/default.store` **미삭제** 확인.

### Skills
`/grill-with-docs`(store URL·복구전략·샌드박스 파일접근 설계) · `/tdd`(복구 레드퍼스트) · `/swiftui-build-qa` · `/safetywalk-qa-guardrails`.

### 진행 / 보고
main에서 브랜치 `wo9-mac-sandbox-fallback`. handoff 형식 + **macOS Release 실행 스샷(크래시 안 남)** + 테스트 결과 + 샌드박스 후 리포트 export 확인. push는 하되 main 머지는 플래너 검수 후.

**WO-9 결과:**
- 상태: ✅ 완료 · 플래너 검수 통과 · main 머지 (2026-07-08, merge `a8f9f09`). 플래너 재검증(러버스탬프X): 52/52 직접 실행 · Release를 이 맥에서 직접 구동(크래시 0, 8초+ 생존, 관리 대시보드 렌더 육안) · default.store inode/mtime 불변 · 샌드박스 컨테이너에 새 store 생성 확인 · codesign 엔타이틀먼트 3키 확인 · DEBUG(샌드박스+시드) 대시보드 위험색 의미 유지 육안 · 스키마/모델/마이그레이션 diff 0.
- 요약:
  - **① 샌드박스**: `SafetyWalkMac.entitlements`에 `com.apple.security.app-sandbox` + `network.client` + `files.user-selected.read-write`(NSSavePanel export 유지용 — 착수 전 게이트 보고 → 플래너 승인) 추가. 서명 바이너리에 3개 키 포함 확인(`codesign -d --entitlements`). 저장소가 앱 컨테이너(`~/Library/Containers/com.gwonbyeonghag.safetywalk.mac/…/default.store`)로 이동 → 공용 `~/Library/Application Support/default.store`(낡은 스키마) 미사용 → **Release 크래시 소멸**.
  - **② 폴백 팩토리**: `SafetyWalkCore/ModelContainerFactory.swift` 신설 — `SafetyWalkModelContainer.makeCloudKitContainer(containerID:)`. CloudKit+마이그레이션 생성 실패 시 store(`default.store`/`-shm`/`-wal`)를 `.<timestamp>.bak`로 **이동(보존, 삭제 아님)** → fresh 재시도 → 최후 in-memory. `fatalError` 제거. iOS `SafetyWalkApp.swift` + macOS `MacModelContainer.swift`(#else) 둘 다 이 팩토리로 교체. **iOS는 명시 url 미도입 = 저장소 위치 불변 → 기존 데이터 고아화 없음**(게이트 보고 → 승인). macOS `#if DEBUG` 시드 경로 무변경. 스키마/모델/마이그레이션 무변경.
  - **F-1 부수 해소**: 초기화(erase) sim에서 iOS 첫 실행 온보딩이 **정상 표시**(리뷰 때 스프링보드만 → 팩토리 라우팅 후 렌더). 영속 store 3파일(`default.store`/`-wal`/`-shm`) 생성 확인 = 해피패스(in-memory 폴백 아님, 기본 위치 유지).
  - **테스트**: `/tdd` 레드퍼스트로 복구 로직 3종 신규. Core `swift test` = 52 tests green, exit 0.
- 증거 위치:
  - macOS **Release 크래시 無** 대시보드(스샷): `scratchpad/wo9_mac_release_dashboard.png`
  - macOS DEBUG(샌드박스+시드) 브라우즈/데이터 렌더: `scratchpad/wo9_mac_debug_dashboard.png`
  - iOS 초기화 sim 첫 실행 온보딩: `scratchpad/wo9_ios_onboarding.png`
  - 원본 `~/Library/Application Support/default.store` **미삭제**: inode 157337411 / mtime 2026-07-07 15:22 (Release 실행 전후 동일)
  - 복구 로직 테스트: `SafetyWalkCore/Tests/SafetyWalkCoreTests/ModelContainerFactoryTests.swift` (3), `swift test` 52 green
- 잔여(플래너 확인 필요):
  - 리포트 PDF export **NSSavePanel 저장 클릭스루**는 대화형이라 헤드리스 자동화 불가(터미널 Accessibility 권한 없음). 엔타이틀먼트 존재 + 임시디렉터리(컨테이너 내) PDF 생성 = 검증됨. 샌드박스 설계상 사용자 패널 선택으로만 완결 → **실제 저장 1회 수동 확인 권장** → 플래너 검수 시 GUI 자동화(Stage Manager)로 완결 못 함 — **오너 1클릭 확인으로 이관**(리포트→PDF 내보내기→저장).
  - `swift test` 종료 시 CoreData atexit `signal 6` 로그 = 결과 기록 후 발생, exit code 0, 다중 온디스크 컨테이너 하니스 아티팩트(테스트 실패 아님, 신규 테스트 단독 실행 시 미발생).

---

## WO-6 — App Store 동시출시 준비 (제출 자료 일체) 🔴 OPEN

> v2 기능·디자인·크래시fix 전부 완료. 이 WO = **계정 없이 만들 수 있는 제출 자료 전부**를 실행자가 준비하고, App Store Connect 업로드·제출은 **오너 체크리스트**(§오너)로 분리. 코드 변경은 사실상 0(스샷용 데이터 입력·아카이브 검증만).

### 목표 (verifiable)
`docs/appstore/`에 **제출 자료 풀세트**: 규격 스크린샷(iOS+iPad+macOS, ko/en) · 메타데이터 초안(ko/en) · 개인정보 처리방침 · App Privacy 설문 답안 · 심사 메모. **양 타깃 Release 아카이브 빌드 성공 확인.** 코드/모델/버전 무변경(버전 1.0/1 유지 — 첫 공개 릴리스).

### 산출물 (docs/appstore/)
1. **스크린샷** — populated 데이터로(시드 없으니 시뮬에서 직접 입력: 현장 2·점검 1완료·위험요인 3[상중하]·위험성평가 4기법 각1):
   - iPhone 6.9"(iPhone 16 Pro Max 시뮬, 1320×2868) 5~6장: 홈·점검 체크리스트·위험요인·위험성평가(매트릭스 입력)·리포트 미리보기
   - iPad 13"(iPad Pro 13 시뮬, 2064×2752) 2~3장: split view 홈·위험성평가
   - macOS(2880×1800) 2~3장: 관리 대시보드·리포트 허브 (DEBUG 시드 사용 가능)
   - 각 ko 우선, 여력 되면 en. 다크 1~2장 섞기. `xcrun simctl io screenshot` + macOS는 창 캡처.
2. **metadata_ko.md / metadata_en.md**: 앱명("현장 안전 지킴이 - SafetyWalk" 계열, 30자)·부제(30자)·프로모션(170자)·설명(4000자, 위험성평가 4기법+리포트+동기화 중심, "기록 도구이지 판정 아님" 면책 톤 유지)·키워드(100자: 위험성평가,안전점검,JSA,TBM,건설안전…)·지원 URL 제안·카테고리(비즈니스)·연령(4+).
3. **privacy_policy.md**: 수집 데이터 0 · 모든 데이터는 사용자 iCloud 개인 DB(CloudKit private)와 기기 내 저장 · 제3자 공유 없음 · 사진은 사용자 첨부용. (오너가 GitHub Pages 등에 게시할 원문.)
4. **app_privacy_answers.md**: Connect "앱 개인정보 보호" 설문 예상 문항별 답("데이터 수집 안 함" 근거 포함) + 암호화 수출규정(표준 암호화만 = 면제, `ITSAppUsesNonExemptEncryption=NO` 권고 여부 명시).
5. **review_notes.md**: 심사원용(ko/en) — 테스트 방법(온보딩→점검→위험성평가), iCloud 필수 아님(로컬 동작), 면책 고지 위치.
6. **아카이브 검증**: `xcodebuild archive` 양 타깃 성공(서명은 자동, 실패 시 로그만 보고 — 업로드는 오너).

### 🚫 금지 / 중단
- 코드·모델·번들ID·버전·엔타이틀먼트 변경 금지(아카이브 실패가 코드 원인이면 **멈추고 보고**).
- 스샷은 본인 앱 화면만. 과장 문구·"판정/인증" 뉘앙스 금지(CLAUDE.md 도메인 프레이밍: 기록).

### 완료 보고
스샷 목록(규격 확인)·메타데이터 전문·아카이브 결과 → 플래너 검수(규격·문구·면책 톤) 후 오너 체크리스트 발동.

**WO-6 결과:**
- 상태: ☐ 미착수
- 요약:
- 증거 위치:

### §오너 체크리스트 (Connect — 실행자 자료 검수 후)
1. developer.apple.com → Identifiers에 두 번들ID 확인(자동 생성돼 있을 것) → App Store Connect → "나의 앱" → **＋ 신규 앱 2건**(iOS: `com.gwonbyeonghag.safetywalk` / macOS: `com.gwonbyeonghag.safetywalk.mac`, 이름·기본언어 ko, SKU 자유).
2. privacy_policy.md를 URL로 게시(GitHub Pages 권장) → 두 앱에 URL 입력.
3. 메타데이터·스크린샷 업로드(실행자 산출물 그대로) · 가격 무료 · 앱 개인정보 설문(app_privacy_answers.md 따라).
4. Xcode → Product→Archive(타깃별) → Organizer→Distribute→App Store Connect 업로드.
5. 빌드 연결 → 심사 메모 붙여넣기 → **두 앱 동시 제출**.

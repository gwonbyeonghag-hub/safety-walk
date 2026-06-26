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
2. 각 WO의 **수용 기준(Acceptance)** 을 **증거와 함께** 충족시킨다 — 빌드 로그 / 스크린샷 / `git diff` / 테스트 결과.
3. WO 완료 시 그 WO 섹션에 **결과 요약 + 증거 위치**를 적고 `[x]` 처리한다. 임의로 다음 WO로 넘어가지 않는다.
4. 막히거나 결정이 필요하면 **멈추고 질문**한다 (CLAUDE.md 행동지침 1: 가정 금지).
5. 플래너는 완료된 WO를 `V2_ROADMAP.md` / `CLAUDE.md` 규칙 대비 **검토**하고 다음 WO를 연다.
6. **스코프 밖 작업 금지** — WO에 없는 "개선"·리팩터·기능 추가는 하지 않는다 (행동지침 2·3).

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
**WO-0 ✅ 완료 · WO-1 🔴 OPEN(아래 상세).** WO-2 이후는 WO-1 완료·검토 후 작성된다.

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

## WO-1 — 공유 패키지 `SafetyWalkCore` 추출 🔴 OPEN

> 골격은 위키 워크플로우 지식 적용: 목표→범위→완료조건→중단조건→금지→검증 순서
> (`ai-agent-harness-engineering`·`ai-native-workflow-redesign`의 "위임 계약"),
> verifiable goal(`ai-agent-goal-command`), 자가 검증 루프 Trigger→State→Plan→Work→Evaluate→Gate→Memory
> (`ai-agent-loop-engineering`), 검토자 분리(`ai-code-review-quality-harness`).

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
| "테스트 통과" | "패키지 테스트 + 앱 테스트 스위트 모두 green (기존 39테스트 보존)" |
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
- [ ] 테스트: 패키지 테스트 + 앱 테스트 모두 green (로더 테스트가 패키지 쪽에서 통과)
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

**WO-1 결과:**
- 상태: ☐ 미착수
- 요약:
- 증거 위치:

---

## 부록 A — 사전요건(실행자 환경 가정)

- macOS + Xcode (iOS 17+ / 향후 macOS 14+ SDK)
- 이 repo에 대한 push 권한 (GitHub `safety-walk`)
- CloudKit/Apple 계정 작업은 **WO-3 이전엔 불필요** — WO-0~2는 계정 없이 진행 가능

## 부록 B — 검토 체크리스트 (플래너용)

각 WO 검토 시: ① Acceptance 증거 실재 확인 ② `CLAUDE.md` 규칙 위반 없음(도메인 용어/현지화/스코프)
③ 스키마 변경 시 `SWIFTDATA_MIGRATION.md` 절차 준수 ④ 스코프 크리프 없음 ⑤ iOS 빌드 그린 유지.

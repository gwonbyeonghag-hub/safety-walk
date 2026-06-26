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
| 기획 문서 (현재) | repo **바깥** 부모 폴더 `09_현장 안전 지킴이/` 에 산재 — **WO-0에서 repo 안으로 이동** |
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
**현재 열려 있는 WO는 WO-0 하나뿐.** WO-1 이후는 WO-0 완료·검토 후 작성된다.

---

## WO-0 — 구조 재편 (repo 정리 + 문서 편입) 🔴 OPEN

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
- [ ] `.gitignore` 존재, `git status`에 `build/`·`*.xcuserstate`·`.DS_Store` 안 보임 (증거: `git status` 출력)
- [ ] 기존 미커밋 작업물이 의미 있는 커밋으로 보존됨 (증거: `git log --oneline -5`)
- [ ] 12개 기획문서 + `docs/` + `.skills/` 가 repo 안에 있고 추적됨 (증거: `git ls-files | grep -E "CLAUDE|V2_ROADMAP|CONTEXT"`)
- [ ] GitHub에 푸시 완료, 원격에서 `CLAUDE.md`·`V2_ROADMAP.md` 보임 (증거: `git log origin/main --oneline -1` 또는 GitHub URL)
- [ ] iOS 앱 **여전히 빌드 그린** (구조 이동이 Xcode 프로젝트 참조를 깨지 않았는지 — 문서 이동이라 영향 없어야 함; 빌드로 확인)

**하지 말 것:**
- repo의 기존 커밋 히스토리/원격을 새로 init 하거나 갈아엎지 말 것 (히스토리+remote 보존).
- 소스 코드 로직 변경 금지 (이 WO는 **구조/문서만**).
- WO-1(패키지 추출) 시작 금지 — WO-0 검토 통과 후 플래너가 WO-1을 연다.

**WO-0 결과 (실행자 작성):**
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

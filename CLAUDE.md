# CLAUDE.md — SafetyWalk / 현장안전 지킴이

Industrial safety inspection app. SwiftUI, SwiftData.
**v1**: iPhone-first, offline-first (App Store 제출 직전 — stable core).
**v2 (현재 진행)**: iOS + 네이티브 macOS 동시출시 / CloudKit 동기화 / 위험성평가(4기법) / 공유 패키지 `SafetyWalkCore`.
→ v2 마스터 계획은 **`V2_ROADMAP.md`** 를 먼저 읽을 것. See also CONTEXT.md, PRD.md, DOMAIN_TERMS.md, TASKS.md.

---

## Behavioral Guidelines

LLM 코딩 실수를 줄이는 행동지침. 사소한 작업엔 판단껏.
출처: `multica-ai/andrej-karpathy-skills`(MIT, 확인일 2026-07-20)의 4원칙을 우리 맥락으로 번안. 원 출처는 Andrej Karpathy X 게시글 `x.com/karpathy/status/2015883857489522876`.

1. **Think before coding** — 가정은 명시. 해석이 갈리면 묻는다(임의 선택 금지). 더 단순한 길이 있으면 말한다. 모르면 멈추고 질문.
2. **Simplicity first** — 문제를 푸는 최소 코드. 요청 안 한 기능·추상화·"유연성"·불가능 케이스 방어 금지. 200줄이 50줄로 되면 다시 쓴다.
3. **Surgical changes** — 건드릴 것만. 인접 코드/포맷 "개선" 금지. 기존 스타일 따른다. 내 변경이 만든 orphan만 정리, 기존 dead code는 언급만.
4. **Goal-driven execution** — 작업을 검증 가능한 목표로. "검증: [체크]"를 단계마다. 빌드/테스트로 루프 종료 조건 확인.

---

## Core Rules

- **Shared core (v2)**: 모델·enum·서비스·템플릿·현지화는 **`SafetyWalkCore` 패키지가 단일 소스**. iOS·macOS 양쪽이 의존. 모델을 타깃별로 복붙 금지(드리프트).
- **iPhone = 현장 도구**: 44×44pt min, no horizontal scroll on main flow, one-handed risk buttons. iOS 홈은 대시보드가 아니다(아래).
- **macOS = 매니저 대시보드/리포트 허브**: 대시보드·인쇄·PDF는 Mac이 담당.
- **Offline-first + CloudKit (v2)**: 풀 워크플로는 **오프라인만으로 완결**돼야 함. CloudKit은 그 위의 동기화 계층. CloudKit 제약 준수(아래 Models).
- **No legal judgment**: 법적 위반/적합을 판정·표시하지 않음. OSHA/KOSHA 하드코딩 금지. **위험성평가도 "판정"이 아니라 사용자 입력 "기록"** — 면책 고지 필수.
- **Localization**: 모든 사용자 문자열은 `Localizable.strings`(en+ko) + `LocalizationKey`. EN/KO 키 패리티 유지.
- **Templates/matrix in data**: 점검 항목·위험성평가 매트릭스(밴드 경계 등)는 데이터/JSON. Swift 배열 하드코딩 금지.
- **SwiftData models**: v1 스키마는 동결이었으나 **v2에서 CloudKit + 위험성평가로 개정 승인됨**. 변경은 반드시 `V2_ROADMAP.md`/`SWIFTDATA_MIGRATION.md` 마이그레이션 플랜을 거친다.
- **Domain terms**: 모델/enum/라벨 이름은 DOMAIN_TERMS.md와 정확히 일치.
- **MVVM**: View ↔ ViewModel 바인딩; Service는 주입(View에서 싱글톤 호출 금지).

---

## What Not to Do

- No features outside PRD.md / V2_ROADMAP.md without asking
- **iPad는 지원됨** (v2 WO-7, 2026-07 방향 전환 — 오너 요청). 앱은 유니버설(`TARGETED_DEVICE_FAMILY = 1,2`). iPad regular width는 `NavigationSplitView`(사이드바+디테일)로 iPad-네이티브하게, iPhone/compact는 기존 탭바+스택 그대로. **iPhone 레이아웃을 늘린 모양 금지 — 기존 iOS 콘텐츠 뷰를 재사용**해 iPad 셸만 얹는다. (구 규칙 "No iPad-specific layouts"는 폐기.)
- **Checklists stay Pass/Fail/NA** — 점수/가중치는 점검표가 아니라 **위험성평가 모듈(빈도×강도)에서만** 존재
- No hard-coded strings or legal text in Swift/SwiftUI source
- **iOS 홈은 대시보드 금지** — glanceable 현장 도구(위험요인 risk rail·빠른 액션·최근 점검). dense-but-calm, action-oriented. (대시보드는 **macOS**에서.)
- Do not rename domain terms without updating DOMAIN_TERMS.md first

---

## QA Skills

Run these before completing any relevant task:

- `/navigation-qa` — after any navigation or screen transition change
- `/screen-implementation-review` — before marking any screen task done
- `/checklist-template-expansion` — when adding or modifying template items
- `/design-visual-qa` — after functional QA passes, before marking any screen done (render → screenshot → critique loop)
- `/swiftui-build-qa` — before reporting any SwiftUI screen task complete: signed iOS/macOS build + test-destination verification + SwiftUI type-inference error rules (apply proactively when writing new View code)
- `/safetywalk-qa-guardrails` — whenever doing QA, simulator testing, seed-data injection, build cleanup, or pre-TestFlight verification (the project's QA + simulator/build hygiene checklist)

---

## Key Files

| File | Purpose |
|---|---|
| **V2_ROADMAP.md** | **v2 마스터 계획**: 결정·아키텍처·빌드 순서·사전요건 (먼저 읽기) |
| CONTEXT.md | Problem, users, constraints |
| PRD.md | Features and acceptance criteria |
| DOMAIN_TERMS.md | Canonical terminology and enum definitions |
| TASKS.md | Dev task list |
| SWIFTDATA_MIGRATION.md | Frozen schema baseline + post-launch model-change/migration policy |
| APP_STORE_SUBMISSION.md | App Store metadata / privacy / screenshots / reviewer notes drafts + pre-submit checklist |
| SafetyWalkCore/Sources/SafetyWalkCore/Resources/ | Checklist JSON templates (korea + global) |
| Utilities/LocalizationKey.swift | Type-safe string access |

---

## SwiftData Models (v1 — v2에서 CloudKit/위험성평가로 개정 중)

모델: Site · Area · Inspection · ChecklistItem · Hazard · RiskAssessment(v2). 컨테이너에 등록된 전체 목록은 `SafetyWalkCore/Sources/SafetyWalkCore/Migration/SchemaV3.swift`.
필드 정의의 진실은 `SafetyWalkCore/Sources/SafetyWalkCore/` 소스이며, 설계 근거는 `V2_ROADMAP.md` AD-3, 마이그레이션 정책은 `SWIFTDATA_MIGRATION.md`.

**CloudKit 제약 (WO-3에서 실제 적용, 크래시로 검증됨):** 모든 속성은 optional 또는 **기본값 보유**; 관계는 **optional**(`[ChecklistItem]?`); **모든 관계는 inverse 필수**(`@Relationship(inverse:)` — 없으면 "CloudKit integration requires that all relationships have an inverse" 런타임 크래시. 문서/역할상 관계를 안 쓰는 쪽에도 inverse 전용 프로퍼티를 추가해야 함, 예: `Area.site: Site?`, `ChecklistItem.inspection: Inspection?` — 앱 코드는 계속 UUID 필드로 조회, inverse 프로퍼티는 읽지 않음); `@Attribute(.unique)` 금지; 사진은 `photoPath` 대신 `@Attribute(.externalStorage) Data`(`photoData`)로 동기화. 마이그레이션은 VersionedSchema(`SafetyWalkCore/Sources/SafetyWalkCore/Migration/`)로 — 자세한 내용은 SWIFTDATA_MIGRATION.md.

**기본값과 미기록은 다르다 (교정 #3 / LEGAL-0):** 위 "기본값 보유"는 CloudKit 요구사항이지 값 설계 지침이 아니다. **사용자가 기록하는 사실 필드(위험도·평가값·참여자 등)는 `Optional` + `nil = 미기록`으로 두고, 자동 기본값이 미기록을 대신하지 않게 한다.** 렌더링은 `nil`을 "미기록 / Not recorded"로 표시하고 실제 값처럼 계산에 넣지 않는다. 적용 예: `RiskAssessmentItem.riskLevel`, `BriefingRiskItemSnapshot.riskLevel` — 리포트 렌더 테스트가 이 표시를 강제한다.

---

## Agent skills

### Issue tracker

Issues for this repo are tracked in GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

Default canonical label vocabulary (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo — one `CONTEXT.md` and `docs/adr/` at the project root. See `docs/agents/domain.md`.

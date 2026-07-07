# V2_ROADMAP.md — SafetyWalk / 현장안전 지킴이 (v2 멀티플랫폼)

> 작성: 2026-06-26. 이 문서는 v2의 **마스터 계획**이다.
> v1(iOS, 제출 직전)에서 → **iOS + 네이티브 macOS 앱 동시출시**로 확장한다.
> 결정 사항·아키텍처·단계·"필요한 것"을 한곳에 모은다. 세부 스펙은 단계 착수 시
> CONTEXT/PRD/DOMAIN_TERMS에 반영한다.

---

## 0. 확정 결정 (2026-06-26, 오너 승인)

| # | 항목 | 결정 | 이유 / 결과 |
|---|---|---|---|
| D-1 | Mac 앱 방식 | **네이티브 macOS 별도 앱** | 매니저용 대시보드를 가장 이쁘게. 단, 코드 재사용을 위해 공유 패키지 추출이 전제(AD-1) |
| D-2 | 동기화 | **CloudKit (iCloud)** | Apple 기기 전용·무료·서버 불필요. SwiftData와 직접 연동. 웹/안드 확장은 포기 |
| D-3 | 위험성평가 기법 | **4종 전부**: ①3단계 상·중·하 ②빈도×강도 매트릭스 ③체크리스트법 ④해외 JSA/JHA | 기법은 데이터/설정으로 추상화(AD-3) |
| D-4 | 출시 전략 | **v2로 전부 묶어 동시출시** | iOS 업데이트 + macOS 신규 앱 동시 제출 |

### 오너에게 솔직히 짚는 현실 (decision은 존중하되 리스크 명시)
- **일정 리스크**: CloudKit + 별도 macOS + 위험성평가 4종이 전부 신규다. "동시출시"는
  v1 단독 출시보다 **출시 시점이 크게 밀린다**. → 권고: **빌드는 안전한 순서로 단계화**하되
  (각 단계마다 iOS는 출시 가능 상태 유지), **제출만 동시에** 한다. (§3 빌드 순서)
- **동결 스키마가 깨진다**: `SWIFTDATA_MIGRATION.md`의 frozen v1 스키마는 CloudKit 제약 +
  신규 모델로 **반드시 개정**된다. 이는 v2 결정에 따라 승인된 변경으로 간주.
- **"대시보드 금지" 규칙 범위 축소**: 현재 `CLAUDE.md`의 "No marketing/metrics dashboard"는
  **iOS 홈에만** 적용. macOS는 대시보드가 메인이 된다(AD-4).
- **법적 프레이밍 유지**: 위험성평가도 "판정"이 아니라 **기록**이다. 위험성 수준(상/중/하·점수)과
  감소대책은 사용자가 입력/선택한 기록일 뿐, 앱이 법적 위반·적합을 판정하지 않는다. 면책 고지 확장(AD-3).

---

## 1. 출발선 (v1에서 이미 가진 것)

- iOS 앱 거의 완성: SwiftUI / iOS 17+ / SwiftData / 오프라인 우선. 72개 중 70개 완료, 빌드 클린.
- **한국/해외 2개 프로파일 존재**: `checklist_korea.json`(KOSHA 테마) + `checklist_global.json`
  (미국 OSHA·imperial). → **해외(미국) 버전 뼈대 이미 있음.**
- EN/KO 현지화 300=300, `LocalizationKey` 타입세이프 접근.
- 흐름 완성: 점검(Inspection) → 위험요인(Hazard) → 시정조치 → 리포트 Export(이미지/단일 PDF).
- QA 스킬 6종(`.skills/`), 도메인 문서(CONTEXT/PRD/DOMAIN_TERMS/TASKS) 정비.

## 1.5 새로 필요한 것 (v2 신규)

1. **공유 도메인 패키지** `SafetyWalkCore` (모델·enum·서비스·템플릿·현지화)
2. **위험성평가 모듈** (모델 + 4기법 + 화면 + 리포트) — 현재 전무
3. **CloudKit 동기화 계층** (엔타이틀먼트 + 스키마 개정 + 사진 동기화 + 마이그레이션)
4. **네이티브 macOS 앱** (대시보드 + 위험성평가 관리 + 인쇄/PDF 리포트)
5. **리포트 고도화** (멀티페이지 A4/Letter, 위험성평가표, JHA 워크시트, 인쇄 품질)
6. **디자인 폴리시** 양 플랫폼

---

## 2. 아키텍처 결정 (AD)

### AD-1 — 공유 패키지 `SafetyWalkCore` (Swift Package)
양쪽 앱이 의존하는 단일 소스. 포함:
- `Models/` (SwiftData @Model: Site, Area, Inspection, ChecklistItem, Hazard, **+ RiskAssessment 신규**)
- `Models/Enums.swift`
- `Services/` 플랫폼 무관 로직: `ChecklistTemplateLoader`, `PhotoStorageService`(추상화),
  `InspectionExportService`의 데이터 준비 로직
- `Resources/Templates/*.json`, `Resources/Localization/*` (패키지 리소스 번들)
- 플랫폼 분기(`#if os(iOS)` / `#if os(macOS)`)는 UIImage/NSImage 등 최소 지점에만.
- **근거**: 별도 macOS 앱 + CloudKit = 동일 스키마·동일 컨테이너 필수. 모델 복붙은 드리프트 보장.

### AD-2 — CloudKit 동기화 (SwiftData + CloudKit)
- `ModelConfiguration(..., cloudKitDatabase: .private("iCloud.com.<team>.safetywalk"))`.
- 양쪽 앱 엔타이틀먼트에 **동일 iCloud 컨테이너 ID** + iCloud(CloudKit) capability + Background Modes(remote notifications).
- **CloudKit 제약 → 스키마 개정 필수 (v1 모델 감사 결과):**
  - 모든 속성은 optional 이거나 **기본값 보유**해야 함. (현재 `siteId: UUID`, `status`, `inspectorName` 등 비옵셔널·기본값 없음 → 수정)
  - **관계는 optional이어야 함**: `@Relationship var items: [ChecklistItem]` → `[ChecklistItem]?` (현재 비옵셔널 → 수정)
  - **관계는 inverse 필수** (WO-3 실기기/시뮬레이터 실행 중 발견 — 위 3개 항목만으로는 부족): inverse 없으면 "CloudKit integration requires that all relationships have an inverse" 런타임 크래시. `Site.areas`/`Inspection.items`/`Inspection.hazards`/`RiskAssessment.items` 전부 해당 → 상대편(`Area`/`ChecklistItem`/`Hazard`/`RiskAssessmentItem`)에 inverse 전용 프로퍼티 추가 필요(앱 코드는 계속 UUID로 조회, 이 프로퍼티는 CloudKit 스키마 검증용으로만 존재). 이 때문에 v1↔v2 마이그레이션 대상이 애초 예상(ChecklistItem/Hazard의 photoPath만)보다 넓어져, 관계 그래프에 걸린 7개 모델 전부 SchemaV1 재선언이 필요해짐 — 상세: SWIFTDATA_MIGRATION.md.
  - `@Attribute(.unique)` **사용 불가** (현재 미사용 — OK 유지)
  - enum은 String Codable이면 OK (현재 OK)
- **사진 동기화 (현재 `photoPath: String` = Documents 파일이라 동기화 안 됨):**
  - 안: 모델에 `@Attribute(.externalStorage) var photo: Data?` 추가 → SwiftData가 CKAsset로 자동 동기화.
  - 기존 파일 사진 → Data 마이그레이션 필요. (대안: iCloud Drive 별도 동기화 — 더 복잡, 비채택 권고)
- **마이그레이션**: frozen v1(로컬 전용) → v2(CloudKit + 신규 필드). VersionedSchema + Migration plan 작성.
- 충돌 처리/오프라인 큐잉은 CloudKit 기본 동작에 위임(필드 단위 last-writer-wins).

### AD-3 — 위험성평가 모듈
- 신규 모델 `RiskAssessment` (= 한 건의 위험성평가표). 보유: 평가일, 평가종류(최초/정기/수시),
  현장/구역, 평가자, 기법, 항목들(`RiskAssessmentItem`), 면책 고지.
- `RiskAssessmentItem`: 공정/작업·유해위험요인·현재안전조치·**위험성 산정**·감소대책·개선후 위험성·담당/기한.
- **기법은 설정으로 추상화** (`RiskAssessmentMethod` enum):
  | 기법 | 입력 | 산정 |
  |---|---|---|
  | `.threeLevel` 3단계 | 위험성 수준 직접 상/중/하 | 그대로 |
  | `.frequencySeverity` 빈도×강도 | 가능성(빈도) × 중대성(강도) | 곱/표 → 등급 밴드(상/중/하 or 점수) |
  | `.checklist` 체크리스트법 | 기존 점검표 부적합 항목 연계 | 부적합→위험성 |
  | `.jsa` JSA/JHA(해외) | 작업단계별 hazard·controls | 미국식 워크시트 |
- 매트릭스 크기/밴드 경계는 **설정 데이터**(3x3·4x4·5x5, 점수→상중하 매핑)로. 코드에 하드코딩 금지.
- 한국 법 프레이밍: 정기 위험성평가 ≥ 연 1회. 앱은 **리마인더/기록**만, **판정 안 함**.
- 기존 `Hazard.riskLevel`(단순 상/중/하)과의 관계: Hazard는 현장 즉시기록, RiskAssessment는 정식 평가표.
  RiskAssessmentItem이 Hazard를 참조할 수 있게 연결(선택).

### AD-4 — macOS = 매니저 대시보드 (메인 화면이 대시보드)
- iOS 홈은 "현장 도구"로 유지(대시보드 금지 규칙 그대로). **대시보드는 Mac이 담당.**
- Mac 대시보드 구성(안): 현장별 위험요인 현황, 미완료 시정조치, 위험성평가 due(연1회 알림),
  최근 점검, 위험등급 분포. (위키 대시보드 톤 참고 — calm·dense·action)
- Mac은 **리포트 생성/인쇄 허브**: 큰 화면에서 위험성평가표·점검 리포트를 이쁘게 뽑고 인쇄/PDF.

### AD-5 — 리포트 고도화
- 현재 단일 tall PDF → **멀티페이지 A4(KR)/Letter(US)**, 마스트헤드·페이지번호·면책 고지.
- 양식: ①점검 리포트 ②**위험성평가표(KR)** ③**JHA 워크시트(US)**.
- "이쁘게": 표 정렬·사진 그리드·위험등급 색 밴드·로고. Mac에서 인쇄 품질 우선.
- (선택, 후순위) 이쁜 PDF/무제한 현장 = 유료(Pro) 후보 — `MONETIZATION_STRATEGY.md` 연계, v2.0엔 비차단.

### AD-6 — 지역/현지화 확장
- 기존 Korea/Global 프로파일에 **위험성평가 기본 기법 + 리포트 양식**을 부착.
  - KR → 빈도×강도(기본) 또는 3단계 선택, 위험성평가표.
  - US → JSA/JHA, JHA 워크시트.
- 신규 문자열은 EN/KO 동시(키 패리티 유지 규칙 그대로).

---

## 3. 빌드 순서 (단계화하되 제출은 동시)

> 원칙: **각 단계 종료 시 iOS는 항상 빌드·출시 가능 상태**. 위험한 리팩터는 단계 분리 + 검증.
> git: iOS 레포가 "Initial Commit" 1개 + 미커밋 변경 다수 → **Phase 1 전 커밋/브랜치 정리 필수**.

| Phase | 내용 | 산출/검증 |
|---|---|---|
| **0. 준비 (지금)** | 결정 문서(본 파일)·CLAUDE.md 갱신·docs v2 업데이트·CloudKit 사전요건 체크리스트·위험성평가 설계 확정·git 정리 | 문서 일관, iOS 빌드 그대로 그린 |
| **1. 공유 패키지 추출** `SafetyWalkCore` | 모델/enum/서비스/리소스 → Swift Package. iOS 앱이 패키지 의존. **동작 변화 0** | iOS 빌드+테스트 그린(기존 39테스트), 화면 회귀 없음 |
| **2. 위험성평가 모듈 (iOS 먼저)** | 신규 모델 + 4기법 + 입력 UI + 리포트(KR/US) | iOS에서 4기법 평가 생성·리포트 출력, 테스트 |
| **3. CloudKit 동기화** | 엔타이틀먼트·스키마 감사(옵셔널/기본값/관계)·사진 동기화·v1→v2 마이그레이션·2기기 검증 | 기기A 입력→기기B 반영, 사진 포함, 마이그레이션 무손실 |
| **4. macOS 앱** | 신규 타깃, `SafetyWalkCore` 의존, 대시보드 + 위험성평가 관리 + 인쇄/PDF | 동일 CloudKit 데이터 표시, 대시보드·리포트 동작 |
| **5. 디자인·리포트 폴리시 + US 동시** | 양 플랫폼 디자인 QA, US JHA/리포트 마감, App Store 메타·스크린샷(iOS+macOS) | `/design-visual-qa` 통과, 양 스토어 자료 완비 |
| **6. 동시출시** | iOS 업데이트 + macOS 신규 앱 동시 제출, CloudKit production 배포, 런치 체크 | 양 앱 심사 통과, 프로덕션 동기화 OK |

---

## 4. "필요한 것" (사전요건 / 준비물 체크리스트)

- [ ] **Apple Developer Program** (iOS 제출 직전이니 보유 추정) — macOS 앱 + iCloud 컨테이너 capability 활성
- [ ] **iCloud(CloudKit) 컨테이너 ID 확정** (예: `iCloud.com.<team>.safetywalk`) — 양 앱 공유
- [ ] **사진 동기화 방식 확정**: `@Attribute(.externalStorage) Data` (권고) vs 파일 유지
- [ ] **v1→v2 마이그레이션 플랜** (frozen 스키마 개정 + CloudKit 제약 + 신규 모델)
- [ ] **Mac 디자인 언어** (navy + orange accent 유지, 대시보드 컴포넌트 세트)
- [ ] **US 위험성평가(JHA) 콘텐츠 + 리포트 양식**
- [ ] **위험성평가 매트릭스 기본값** (KR 3x3/4x4 밴드 경계, 점수→상중하 매핑)
- [ ] **git 위생**: iOS 레포 커밋/브랜치 분리 (refactor 전)
- [ ] (선택) **유료화 라인** 결정 — 이쁜 PDF/무제한을 Pro로 둘지

---

## 5. 미해결/추후 결정 (TBD)

- CloudKit 사진: externalStorage Data 전면 전환 시 기존 파일 사진 마이그레이션 절차 상세
- 위험성평가 매트릭스 기본 사이즈(3x3 vs 4x4 vs 5x5) 및 한국 표준 밴드 경계
- macOS 최소 버전(예: macOS 14 Sonoma) — SwiftData/CloudKit 요구사항과 정합
- 팀/다중 사용자(여러 현장 관리자 공유)는 CloudKit private DB 한계 → v2 범위 밖(추후 shared DB)
- 앱 이름 영문(SafetyWalk) macOS 스토어 노출명 / 카테고리

---

## 6. 관련 문서

| 문서 | 역할 |
|---|---|
| CONTEXT.md / PRD.md / DOMAIN_TERMS.md | v2 착수 단계에서 갱신 |
| SWIFTDATA_MIGRATION.md | frozen 스키마 → v2 개정 정책 |
| LAUNCH_CHECKLIST.md / SUBMISSION_RUNBOOK.md / APP_STORE_SUBMISSION.md | 동시출시용 macOS 항목 추가 |
| MONETIZATION_STRATEGY.md | 리포트/Pro 라인 연계 |
| CLAUDE.md | v2 규칙(멀티플랫폼·CloudKit·위험성평가) + 기초자료 행동지침 병합 |

# SCHEMA_V3 v2 — 동결 후보 (오너 승인 대기 · 실제 코드 정박)

> 근거: [ENTITY_MAP](ENTITY_MAP_V3_DRAFT.md)·[LEGAL_2_ARCH](LEGAL_2_ARCH.md)·[TBM_0_ARCH](TBM_0_ARCH.md)·[PRIVACY_AUDIT](PRIVACY_AUDIT.md). v1을 실제 코드와 대조한 오너 리뷰 8건 반영.
> **CloudKit 4확인(2026-07-13)**: TestFlight 없음·Production 스키마 미배포(CD_ 0개)·데이터 없음·로컬 전부 테스트 → **리셋 + V3 첫 출시 baseline**.
> ⚠️ **관통 하드룰(교정 #3)**: 사용자가 기록하는 사실 필드는 **미기록(nil)과 실제 값을 구분**해야 한다 — Bool/자동기본값이 미기록을 숨기면 안 됨(자동-Low 안티패턴 재발 금지).

## 1. SchemaV3 = 총 15 모델 (교정 #1)
```
기존 5 (불변):  Site · Area · Inspection · ChecklistItem · Hazard
기존 2 (확장):  RiskAssessment · RiskAssessmentItem
신규 8:        RiskAssessmentProgram · AssessmentCriteria · CorrectiveAction ·
              RiskAssessmentParticipant · SharingEvent ·
              SafetyBriefing · BriefingParticipant · BriefingRiskItemSnapshot
```
`SchemaV3.models`에 15개 전부 등록. 누락 시 Inspection/Hazard 기능 붕괴.

## 2. VersionedSchema 정책 (교정 #7-baseline)
- `SchemaV3: VersionedSchema`(3.0.0)를 **첫 출시 baseline**. 리셋이므로 `SchemaV1`·`SchemaV2`·`SafetyWalkMigrationPlan`·V1→V2 마이그레이션 테스트 **제거**(선재 플레이크 task_fb1e657c도 소멸).
- **동결 보존 정책**: 출시 후 SchemaV3 형태는 **in-place 수정 금지** — 변경은 반드시 SchemaV4 신설 + 마이그레이션으로.

## 3. 공유·신규 enum (SafetyWalkCore)
```
ParticipantRole : worker · workerRep          ConfirmationMethod : managerRecord · selfConfirm · signature
AssessmentStatus: planned · inProgress · finalized · cancelled     BriefingStatus: draft · conducted · finalized · cancelled
AssessmentParticipationMethod: patrol · interview · survey · other  (평가 전용)   SharingMethod: education · posting · written · electronic (비TBM)
OperatingMode: regular · continuous           ProgramStatus: active · archived
CriteriaDecision: withinThreshold · exceedsThreshold   // nil=미평가 (교정 #3)
WorkerRepStatus : notRequested · requestedNotParticipated · participated   // nil=미기록
SharingPhase    : pre · post                  // nil=미설정
EffectivenessResult: effective · partiallyEffective · ineffective   // 조치 효과확인 결과(교정 #2 — Bool 아님)
// 법규 프로필 = 안정 raw-code enum (표시는 로컬라이즈에서 생성, 교정 #6)
JurisdictionCode  : kr · us                   // ★법적 관할 — RegionProfile(언어-지역)과 별개, 혼용 금지
IndustryProfileCode: general · construction · electric
BriefingProfileCode: krTBM · usCAConstruction · usElectric · usGeneral
// 기존 유지: RiskAssessmentKind · RiskAssessmentMethod · RiskLevel · CorrectiveActionStatus · HazardType · ChecklistItemResult · InspectionStatus
// RegionProfile(korea/global)은 언어-지역 전용으로 유지 — 법적 관할엔 JurisdictionCode 사용
```

## 4. 모델 스펙 (CloudKit: 관계 optional + **inverse 필수**(교정 #2) · 저장속성 기본값 · unique 금지 · 바이너리 externalStorage(교정 #6))

**기존 5 불변**: Site·Area·Inspection·ChecklistItem·Hazard — 현행 그대로(이미 inverse·externalStorage 준수).

```swift
@Model RiskAssessmentProgram {                 // N: 현장별 프로그램. 물리삭제 대신 archived (교정 #1)
  id=UUID(); siteId:UUID?; siteName=""                         // 참조+값 스냅샷
  jurisdiction:JurisdictionCode?; industryProfile:IndustryProfileCode?; profileVersion=1   // 법규 프로필 코드(교정 #6)
  effectiveFrom:Date?; effectiveTo:Date?
  operatingMode:OperatingMode = .regular
  status:ProgramStatus = .active
  createdAt=Date(); updatedAt=Date(); archivedAt:Date?         // archived 시각(교정 #5)
}
@Model RiskAssessment {                        // E: 독립 루트. 기존 필드 전부 보존(교정 #4)
  id=UUID(); kind; method; siteId:UUID?; siteName=""
  assessorName=""                              // ★보존 — 법정 담당자·PDF·Mac·상세
  linkedInspectionId:UUID?                     // ★보존 — 체크리스트법 진입
  note:String?
  // 신규
  programId:UUID?; jurisdictionSnapshot:JurisdictionCode?; industryProfileSnapshot:IndustryProfileCode?; programVersionSnapshot=0   // 참조+값 코드(관계 아님→cascade 없음)
  status:AssessmentStatus = .planned
  scheduledAt:Date?; assessedAt:Date?; finalizedAt:Date?; cancelledAt:Date?; cancellationReason:String?   // 감사·취소 시각(교정 #5·#6)
  createdAt=Date(); updatedAt=Date()
  workerRepStatus:WorkerRepStatus?             // nil=미기록(교정 #3)
  @Relationship(.cascade, inverse:\AssessmentCriteria.riskAssessment) criteria:AssessmentCriteria?
  @Relationship(.cascade, inverse:\RiskAssessmentItem.riskAssessment) items:[RiskAssessmentItem]?
  @Relationship(.cascade, inverse:\RiskAssessmentParticipant.riskAssessment) participants:[RiskAssessmentParticipant]?
  @Relationship(.cascade, inverse:\SharingEvent.riskAssessment) sharingEvents:[SharingEvent]?
}
@Model RiskAssessmentItem {                    // E
  id=UUID(); taskDescription=""; hazardDescription=""; currentControls:String?
  likelihood:Int?; severity:Int?
  riskLevel:RiskLevel?                         // ★optional nil=미평가(교정 #3)
  criteriaDecision:CriteriaDecision?           // nil=미평가, 초과 여부는 사용자 확인
  decisionConfirmedAt:Date?; decisionConfirmedBy:String?   // 확인 시각·확인자(교정 #3)
  linkedHazardId:UUID?; sortOrder=0
  riskAssessment:RiskAssessment?               // inverse
  @Relationship(.cascade, inverse:\CorrectiveAction.item) correctiveActions:[CorrectiveAction]?   // 리셋이라 legacy 이관 없음
}
@Model AssessmentCriteria {                    // N: 1:1 소유·값복사, inProgress 잠금
  id=UUID(); matrixData=Data(); matrixFormatVersion=1   // 포맷버전+디코딩 실패시 fail-closed(교정 #6)
  acceptabilityThreshold=0; lockedAt:Date?
  riskAssessment:RiskAssessment?               // inverse
}
@Model CorrectiveAction {                       // N: 기존 필드 흡수 + finalized 후 수정
  id=UUID(); measure:String?; responsibleName:String?; dueDate:Date?
  status:CorrectiveActionStatus = .notStarted
  implementedAt:Date?; confirmedBy:String?; effectivenessConfirmedAt:Date?   // 감사 시각(교정 #6)
  effectivenessResult:EffectivenessResult?     // nil=미확인. "효과확인됨"은 result≠nil로 파생 (Bool 제거, 교정 #2)
  @Attribute(.externalStorage) evidencePhotoData:Data?
  postRiskLevel:RiskLevel?
  item:RiskAssessmentItem?                     // inverse
  // isRequired = 저장 안 함 → 부모 item.criteriaDecision==exceedsThreshold에서 **파생**(computed). 저장 필요 시 생성자 필수 인자로만(기본값 금지, 교정 #2)
}
@Model RiskAssessmentParticipant {              // N: 소유·불변(finalized)
  id=UUID(); name=""; employeeId:String?; affiliation:String?; jobTitle:String?   // 이름 필수(검증)
  role:ParticipantRole = .worker
  participationMethod:AssessmentParticipationMethod?   // nil=미기록(평가 전용)
  participatedAt:Date?
  confirmationMethod:ConfirmationMethod?; confirmedAt:Date?   // nil=미확인(교정 #3)
  @Attribute(.externalStorage) signatureData:Data?; signedAt:Date?
  riskAssessment:RiskAssessment?               // inverse
}
@Model SharingEvent {                            // N: 비TBM만, 생성 즉시 불변
  id=UUID(); phase:SharingPhase?               // nil=미설정(교정 #3)
  method:SharingMethod?; sharedAt:Date?; target:String?; contentSnapshot=""; ownerName:String?
  riskAssessment:RiskAssessment?               // inverse
}
@Model SafetyBriefing {                          // N: = TBM 공유 증명. Site 참조 UUID(관계 아님→생존)
  id=UUID(); siteId:UUID?; siteName=""; programId:UUID?; assessmentId:UUID?; areaId:UUID?
  briefingProfile:BriefingProfileCode?; taskDescription=""; occurredAt:Date?; location=""   // 프로필 코드(교정 #6)
  status:BriefingStatus = .draft; briefingContent=""; ownerName:String?
  createdAt=Date(); updatedAt=Date(); conductedAt:Date?; finalizedAt:Date?; cancelledAt:Date?; cancellationReason:String?   // 감사·취소(교정 #5)
  retainUntil:Date?                            // 정책 기반, 자동 판정 안 함(교정)
  supersedesBriefingId:UUID?; correctionReason:String?; correctedAt:Date?; correctedBy:String?
  @Relationship(.cascade, inverse:\BriefingParticipant.briefing) participants:[BriefingParticipant]?
  @Relationship(.cascade, inverse:\BriefingRiskItemSnapshot.briefing) riskSnapshots:[BriefingRiskItemSnapshot]?
}
@Model BriefingParticipant {                     // N: 소유·불변(finalized)
  id=UUID(); name=""; employeeId:String?; affiliation:String?; jobTitle:String?
  role:ParticipantRole = .worker
  confirmationMethod:ConfirmationMethod?; confirmedAt:Date?   // nil=미확인, 공유 enum만(순회/면담/설문 재사용 안 함)
  @Attribute(.externalStorage) signatureData:Data?; signedAt:Date?
  briefing:SafetyBriefing?                     // inverse
}
@Model BriefingRiskItemSnapshot {                // N: 값 복사(교정 #3·#5 — 1:N 조치 보존, 문자열 축약 금지)
  id=UUID(); sourceAssessmentId:UUID?; sourceItemId:UUID?   // 출처 추적용
  taskDescription=""; hazardDescription=""; currentControls=""
  riskLevel:RiskLevel?; likelihood:Int?; severity:Int?      // ★정규 값
  controlMeasuresSnapshot=Data(); controlMeasuresFormatVersion=1   // ★1:N 조치 버전형 스냅샷(각 조치 measure·담당·기한·status·postRiskLevel 값 복사; 디코딩 실패 fail-closed)
  displayTextAtBriefing:String?                // 당시 표시 문구(선택 보존)
  briefing:SafetyBriefing?                     // inverse
}
```

## 4.1 생성자 계약 (교정 #4 — CloudKit 기본값 ≠ 업무 필수값)
- CloudKit은 저장속성 기본값을 요구 → **저장속성엔 기본값 유지**. 그러나 **생성자는 업무 필수값을 인자로 강제**(생성자 기본값 금지):
  - `RiskAssessmentProgram`: siteId·siteName·jurisdiction 필수
  - `RiskAssessment`(생성 시): siteId·siteName·kind·method 필수
  - `RiskAssessmentParticipant`·`BriefingParticipant`: **name·role 필수**
  - `SharingEvent`: **phase·method·sharedAt 필수**
  - `SafetyBriefing`: **siteId·siteName 필수**
  - `CorrectiveAction`: **item 연결 필수**. `isRequired`는 **저장 필드도 생성자 인자도 아님** — `item.criteriaDecision == exceedsThreshold`에서 파생(computed).
  - `CorrectiveAction` 효과확인 불변조건: `effectivenessResult`·`effectivenessConfirmedAt`·`confirmedBy`는 **하나의 도메인 동작으로 함께 갱신**(부분 갱신 금지).
- **insert/finalize 전 검증 실패 시 저장 금지**(빈 모델 영속 차단). LEGAL-0의 `save() throws` 방어 패턴 확장.

## 5. 삭제규칙 (inverse 명시)
- **cascade+inverse**: RiskAssessment→(criteria·items·participants·sharingEvents), Item→correctiveActions, Briefing→(participants·riskSnapshots). 기존 Site→areas, Inspection→items·hazards 유지.
- **관계 아님(UUID+값 스냅샷 → cascade 없음, 생존)**: Program↔Site, Assessment↔Program, Briefing↔Site/Program/Assessment/Area.
- **불변조건**: 어떤 상위 삭제도 과거 평가·브리핑을 지우지 않음. Program은 `archived`. 3년 보존=앱 가드(retainUntil).

## 6. 리셋 대상 (교정 #7 — 위험 표현 수정, 코드 정박)
- 앱 store = `URL.applicationSupportDirectory/default.store` → **샌드박스 컨테이너 안**(ModelContainerFactory 주석). **공용 `~/Library/Application Support/default.store`는 대상 아님**(다른 앱/비샌드박스 잔재일 수 있음 → 제외).
- 리셋 대상: **① iOS 시뮬레이터** 앱 컨테이너 store · **② macOS 샌드박스** `~/Library/Containers/com.gwonbyeonghag.safetywalk.mac/Data/…/default.store`.
- 방식 = **삭제 아니라 타임스탬프 백업 이동**(기존 `moveStoreAside` 패턴 재사용) 후 재생성.
- **Development CloudKit reset은 수정된 V3가 iOS·Mac 양 플랫폼 빌드·테스트 통과 후** 실행.

## 7. 코드 강제 불변식
- `riskLevel`·`criteriaDecision`·participation/confirmation·workerRepStatus·phase = **nil이 미기록**. finalize 전 전 항목 위험도+결정 검증. 미평가 절대 Low/기준내 표현 안 함.
- 잠금: Criteria=inProgress · items/participants=finalized · SharingEvent=생성 즉시 · CorrectiveAction=finalized 후 수정 · Briefing content/snapshots=conducted · participants/서명=finalized.
- matrixData 디코딩 실패 = **fail-closed**(미평가 취급, 조용히 진행 금지).

## 8. 구현 순서 (동결·리셋 승인 후)
```
V3 15모델 정의·양플랫폼 빌드/테스트 → [리셋 실행] → 2a 계획·참여자 → 2b 기준·결정 → 2c 조치·개선후 → 2d 비TBM 공유 → 2e 보존/삭제/내보내기 → TBM-1~4 → CONTINUOUS
```

---
## ✅ 오너 최종 동결 승인 요청 (v2 + 6건 봉합)
- **리셋 범위·방식 = 승인됨**(오너). 실제 실행은 V3가 iOS·Mac 빌드·테스트 통과 후에만 — 공용 store 제외·앱 샌드박스 store 백업이동 유지.
- **동결 요청**: 15모델(Program 스펙 포함)·모든 inverse·**nil=미기록**(effectivenessResult·isRequired 파생·profile 코드 enum)·1:N 조치 버전형 스냅샷·**생성자 계약**·cancelledAt/이유·감사시각/externalStorage. → **이 계약 동결 OK?**

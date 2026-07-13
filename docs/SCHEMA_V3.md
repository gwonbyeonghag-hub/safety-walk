# SCHEMA_V3 — 동결 후보 (오너 승인 대기)

> 근거: [ENTITY_MAP_V3_DRAFT](ENTITY_MAP_V3_DRAFT.md) + [LEGAL_2_ARCH](LEGAL_2_ARCH.md) + [TBM_0_ARCH](TBM_0_ARCH.md) + [PRIVACY_AUDIT](PRIVACY_AUDIT.md) + [신뢰출처표](LEGAL_SOURCE_TABLE_KR_US.md).
> **CloudKit 4확인 (2026-07-13)**: TestFlight 없음 · Production 스키마 **미배포**(Record Types=Users만, CD_ 0개, 콘솔 확인) · Production 데이터 없음 · 로컬 보존 없음(전부 테스트).
> **경로 = 리셋 + V3 첫 출시 스키마** (마이그레이션 없음). ⛔ **환경 초기화는 오너 명시 승인 후에만.**

## 1. 리셋 계획 (마이그레이션 아님)
- V1→V2 VersionedSchema·마이그레이션 코드 **제거** — V3가 유일한 출시 baseline.
- **Development** CloudKit 환경 스키마 리셋(기존 CD_ 타입) + 로컬 개발 스토어(`default.store` 등) 초기화 → V3로 재생성.
- **Production**: 이미 비어있음(확인) → 손댈 것 없음. 첫 제출 시 V3 스키마가 신규 배포됨.
- ⚠️ 선재 SchemaMigration 병렬 플레이크(task_fb1e657c)는 리셋으로 **무관해짐**(V1→V2 마이그레이션 테스트 제거).

## 2. 공유 enum (SafetyWalkCore)
```
ParticipantRole            : worker(근로자) · workerRep(근로자대표)
ConfirmationMethod         : managerRecord(관리자출석) · selfConfirm · signature
AssessmentStatus           : planned · inProgress · finalized · cancelled
BriefingStatus             : draft · conducted · finalized · cancelled
AssessmentParticipationMethod : patrol(순회) · interview(면담) · survey(설문) · other   // 평가 전용, TBM 미공유
SharingMethod              : education · posting · written · electronic                 // 비TBM
OperatingMode              : regular · continuous(상시)
ProgramStatus              : active · archived
// 기존 유지: RiskAssessmentKind(initial/regular/occasional) · RiskAssessmentMethod · RiskLevel · CorrectiveActionStatus · RegionProfile
```

## 3. 모델 (CloudKit 규칙: 관계 optional · 저장속성 기본값 · @Attribute(.unique) 금지)

```swift
@Model RiskAssessmentProgram {           // 현장별, 물리삭제 대신 archived
  id = UUID(); siteId: UUID?; siteName = ""          // 참조+값 스냅샷
  jurisdiction: RegionProfile = .korea; industryProfile = ""   // general/construction/electric(LEGAL-3 확장)
  effectiveFrom: Date?; effectiveTo: Date?
  operatingMode: OperatingMode = .regular; status: ProgramStatus = .active; version = 1
}

@Model RiskAssessment {                  // 독립 기록 루트 (Site/Program cascade 안 받음)
  id = UUID()
  siteId: UUID?; siteName = ""                                  // 값 스냅샷(생존)
  programId: UUID?; jurisdictionSnapshot = ""; industryProfileSnapshot = ""; programVersionSnapshot = 0
  kind: RiskAssessmentKind = .regular; method: RiskAssessmentMethod = .frequencySeverity
  status: AssessmentStatus = .planned; scheduledAt: Date?; assessedAt: Date?; finalizedAt: Date?; note: String?
  workerRepRequested = false; workerRepParticipated = false     // 근로자대표 흡수
  @Relationship(.cascade) criteria: AssessmentCriteria?         // 1:1
  @Relationship(.cascade) items: [RiskAssessmentItem]?
  @Relationship(.cascade) participants: [RiskAssessmentParticipant]?
  @Relationship(.cascade) sharingEvents: [SharingEvent]?        // 비TBM
}

@Model AssessmentCriteria {              // 평가 소유·값 복사, inProgress에 잠금
  id = UUID(); matrixData = Data(); acceptabilityThreshold = 0; lockedAt: Date?
}

@Model RiskAssessmentItem {
  id = UUID(); taskDescription = ""; hazardDescription = ""; currentControls: String?
  likelihood: Int?; severity: Int?
  riskLevel: RiskLevel?                                         // ⚠️ optional! nil=미평가 (§2.1 자동Low 차단)
  exceedsThreshold = false                                     // "기준 초과"(자동계산+사용자확인, 법적판정 아님)
  linkedHazardId: UUID?; sortOrder = 0
  @Relationship(.cascade) correctiveActions: [CorrectiveAction]?
}

@Model CorrectiveAction {                // 기존 status·dueDate·responsibleName·감소대책 흡수, finalized 후 수정 가능
  id = UUID(); measure: String?; responsibleName: String?; dueDate: Date?
  status: CorrectiveActionStatus = .notStarted
  implementedAt: Date?; confirmedBy: String?; evidencePhotoData: Data?          // 이행일·확인자·증거
  postRiskLevel: RiskLevel?; effectivenessConfirmed = false; isRequired = false // 개선후위험도·효과확인·필수여부
}

@Model RiskAssessmentParticipant {       // 평가 소유·불변(finalized)
  id = UUID(); name = ""; employeeId: String?; affiliation: String?; jobTitle: String?  // 이름=필수(검증)
  role: ParticipantRole = .worker
  participationMethod: AssessmentParticipationMethod = .patrol  // 평가 전용
  participatedAt: Date?; confirmationMethod: ConfirmationMethod = .managerRecord
  signatureData: Data?; signedAt: Date?                        // 선택 Other User Content
}

@Model SharingEvent {                     // 비TBM 공유만, 생성 즉시 불변
  id = UUID(); isPre = false; method: SharingMethod = .posting; sharedAt: Date?
  target: String?; contentSnapshot = ""; ownerName: String?
}

@Model SafetyBriefing {                   // = TBM 공유 증명 자체. Site 필수(논리)·물리 nullify
  id = UUID(); siteId: UUID?; siteName = ""                    // 값 스냅샷(생존)
  programId: UUID?; assessmentId: UUID?; areaId: UUID?         // 선택
  jurisdictionProfile = ""                                     // 한국TBM/CA/전기/일반
  taskDescription = ""; occurredAt: Date?; location = ""
  status: BriefingStatus = .draft; briefingContent = ""; ownerName: String?
  retainUntil: Date?                                           // 정책 기반, 자동 판정 안 함
  supersedesBriefingId: UUID?; correctionReason: String?; correctedAt: Date?; correctedBy: String?  // 정정 체인
  @Relationship(.cascade) participants: [BriefingParticipant]?
  @Relationship(.cascade) riskSnapshots: [BriefingRiskItemSnapshot]?
}

@Model BriefingParticipant {             // 브리핑 소유·불변(finalized)
  id = UUID(); name = ""; employeeId: String?; affiliation: String?; jobTitle: String?
  role: ParticipantRole = .worker; confirmationMethod: ConfirmationMethod = .managerRecord  // 공유 enum만
  confirmedAt: Date?; signatureData: Data?; signedAt: Date?
}

@Model BriefingRiskItemSnapshot {        // 브리핑 소유 값 복사
  id = UUID(); sourceAssessmentId: UUID?; sourceItemId: UUID?  // 출처 추적용
  hazardDescription = ""; riskLevelDisplay = ""; currentControls = ""; reductionMeasure = ""  // 값 복사
}
```

## 4. 삭제규칙 요약
- **cascade**: RiskAssessment→(criteria·items·participants·sharingEvents), Item→correctiveActions, Briefing→(participants·riskSnapshots).
- **cascade 없음(UUID 참조뿐)**: Site→Program, Program→RiskAssessment, Site/Program/Assessment→SafetyBriefing. Program은 `archived`.
- **불변조건**: 어떤 상위 삭제도 과거 평가·브리핑을 지우지 않음. 3년 보존 = 앱 레벨 가드(`retainUntil`·삭제 UX), 자동 법 판정 없음.

## 5. 코드 강제 불변식 (스키마 아닌 로직)
- `riskLevel` nil=미평가 → **절대 Low로 표현 안 함**. finalize 전 전 항목 위험도 검증.
- 잠금 시점: Criteria=inProgress · items/participants=finalized · SharingEvent=생성 즉시 · CorrectiveAction=finalized 후 수정 · Briefing content/riskSnapshots=conducted · Briefing participants/서명=finalized.
- TBM 공유는 SafetyBriefing 자체(별도 SharingEvent 미생성). 조회 모듈이 SafetyBriefing+SharingEvent 통합.
- 서명=참여·전달 확인(책임포기/법적서명 아님). 이름=필수 검증.

## 6. 동결 후 구현 순서 (승인 후)
```
[리셋 실행(오너 승인)] → 2a 평가계획·참여자 → 2b 기준·기준초과 → 2c 개선조치·개선후위험도
→ 2d 비TBM 공유이벤트 → 2e 3년 보존/삭제/내보내기 → TBM-1~4 → CONTINUOUS(Program 소유)
```
개인정보: `PRIVACY_AUDIT` 최종 제출 게이트(레코드 생성은 WO-A). 참여자=제3자 PIPA 별도.

---
## ✅ 오너 승인 요청
1. **이 스키마 계약 동결** OK?
2. **리셋 실행 승인** (Development CloudKit + 로컬 개발 스토어 초기화 — Production 무관) — 승인 시에만 착수.

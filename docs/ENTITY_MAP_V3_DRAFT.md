# 통합 엔티티 지도 — LEGAL-2 + TBM-0 (SCHEMA-V3 동결 전 초안)

> 상태: **초안 — SCHEMA-V3 동결 아님.** [LEGAL_2_ARCH](LEGAL_2_ARCH.md) + [TBM_0_ARCH](TBM_0_ARCH.md) 합본. 모델·마이그레이션·UI 코드 미작성.
> **관통 패턴**: 소유 자식 = **cascade**. 다른 집합체 참조 = **출처 UUID + 값 복사 스냅샷**(관계 의존 ❌, 원본 삭제 시 생존, nullify).

## 엔티티 (신규 N / 확장 E)
- 위험성평가: `RiskAssessmentProgram`(N) · `RiskAssessment`(E) · `AssessmentCriteria`(N,1:1) · `RiskAssessmentItem`(E) · `CorrectiveAction`(N) · `RiskAssessmentParticipant`(N) · `SharingEvent`(N)
- TBM: `SafetyBriefing`(N) · `BriefingParticipant`(N) · `BriefingRiskItemSnapshot`(N)
- 공유 enum(모델 아님): `ParticipantRole`(근로자/근로자대표) · `ConfirmationMethod`(관리자출석/본인확인/서명)

## 관계 (부모 → 자식)
| 부모 | 자식 | 카디널리티 | 소유 |
|---|---|---|---|
| Site | RiskAssessmentProgram | 1—N | 소유 |
| Site | SafetyBriefing | 1—N (**필수 소속**) | **참조+스냅샷**(선택 관계) |
| RiskAssessmentProgram | RiskAssessment | 1—N | 소유 |
| RiskAssessment | AssessmentCriteria | 1—1 | 소유·불변 |
| RiskAssessment | RiskAssessmentItem | 1—N | 소유 |
| RiskAssessmentItem | CorrectiveAction | 1—N | 소유 |
| RiskAssessment | RiskAssessmentParticipant | 1—N | 소유·불변 |
| RiskAssessment | SharingEvent | 1—N | 소유·불변 |
| SafetyBriefing | BriefingParticipant | 1—N | 소유·불변 |
| SafetyBriefing | BriefingRiskItemSnapshot | 1—N | 소유·불변 |

## 참조(관계 아님 — 출처 UUID + 값 스냅샷)
| 보유자 | 필드 | 가리키는 것 | 규칙 |
|---|---|---|---|
| SafetyBriefing | `siteId` + siteName 값 | Site | Site 삭제해도 브리핑 생존(표시값 스냅샷) |
| SafetyBriefing | `programId`·`assessmentId`(선택) | Program/평가 | 선택 연결, 삭제 시 브리핑 생존 |
| BriefingRiskItemSnapshot | `sourceAssessmentID`·`sourceItemID` | 원본 평가 항목 | 출처 추적용 UUID. 위험요인·수준·조치·대책·문구는 **값 복사** |
| SharingEvent | `sourceBriefingID` | SafetyBriefing | 브리핑 finalize 시 원자 생성. mutable 관계 의존 ❌ |
| SafetyBriefing | `supersedesBriefingID`+correctionReason/At/By | 이전 브리핑 | 정정 체인(중복 아님) |

## 삭제규칙
| 관계 | 규칙 | 이유 |
|---|---|---|
| 소유 자식 전부(Criteria·Item·CorrectiveAction·두 Participant·SharingEvent·BriefingRiskItemSnapshot) | **cascade** | 부모의 일부 |
| Site → SafetyBriefing | **cascade 금지 / nullify** | 과거 브리핑은 표시값 스냅샷으로 독립 생존(교정 #6) |
| 평가/Program → SafetyBriefing·SharingEvent | **cascade 금지** | 출처 UUID+스냅샷이라 원본과 무관 |
| **3년 보존 등 기간** | DB 규칙 아님 → **앱 레벨 가드**(retainUntil·삭제 UX) | 보존은 관할·정책별(교정 #8), 자동 판정 안 함 |

## 수명주기 (둘 다 분리형)
- 평가: `planned · inProgress · finalized · cancelled` + 조치별 상태, `closed`=파생
- TBM: `draft · conducted(내용·위험 잠금, 참석 계속) · finalized(참석·서명 잠금) · cancelled`

## SCHEMA-V3 동결 남은 것 (아직 동결 ❌)
- [ ] 위 표를 SwiftData @Model·`@Relationship(deleteRule:)`로 확정
- [ ] 마이그레이션 vs 리셋 = **오너의 CloudKit 2사실**(TestFlight 배포 · Production 스키마 배포)이 결정
- [ ] `riskLevel: RiskLevel?` optional의 Production 가산 호환 확인
- [ ] 공유 enum 추출 위치(SafetyWalkCore)

# 통합 엔티티 지도 — LEGAL-2 + TBM-0 (SCHEMA-V3 동결 전 최종 초안)

> 상태: **초안 — SCHEMA-V3 동결 아님.** [LEGAL_2_ARCH](LEGAL_2_ARCH.md) + [TBM_0_ARCH](TBM_0_ARCH.md) 합본. 모델·마이그레이션·UI 코드 미작성.
> **불변조건**: 어떤 관계도 **과거 평가·브리핑 기록을 cascade 삭제하지 않는다**(3년 보존 대상). 집합체 간 = 출처 UUID + 값 스냅샷.

## 엔티티
- 위험성평가: `RiskAssessmentProgram`(N,**archived 상태**) · `RiskAssessment`(E,**독립 기록 루트**) · `AssessmentCriteria`(N,1:1) · `RiskAssessmentItem`(E) · `CorrectiveAction`(N) · `RiskAssessmentParticipant`(N) · `SharingEvent`(N,**비TBM 공유만**)
- TBM: `SafetyBriefing`(N,**TBM 공유 증명 자체**) · `BriefingParticipant`(N) · `BriefingRiskItemSnapshot`(N)
- 공유 enum: `ParticipantRole` · `ConfirmationMethod`

## 관계 (부모 → 자식)
| 부모 | 자식 | 카디널리티 | 규칙 |
|---|---|---|---|
| RiskAssessment | AssessmentCriteria / Item / Participant / SharingEvent | 1—N(Criteria 1:1) | **소유·cascade** |
| RiskAssessmentItem | CorrectiveAction | 1—N | 소유·cascade |
| SafetyBriefing | BriefingParticipant / BriefingRiskItemSnapshot | 1—N | 소유·cascade |

## 참조 (관계 아님 — 출처 UUID + 값 스냅샷, nullify, 원본 삭제해도 생존)
| 보유자 | 필드(값 스냅샷) | 가리키는 것 |
|---|---|---|
| **RiskAssessment** | `siteId`·siteName · `programId`·jurisdiction·industryProfile·programVersion | Site / Program (**선택**) |
| SafetyBriefing | `siteId`·siteName · `programId`·`assessmentId`(선택) | Site(필수 논리·물리 nullify) / Program / 평가 |
| BriefingRiskItemSnapshot | `sourceAssessmentID`·`sourceItemID` + 위험요인·수준·조치·대책·문구(값) | 원본 평가 항목 |
| SafetyBriefing | `supersedesBriefingID`·correctionReason/At/By | 이전 브리핑(정정 체인) |

## 삭제규칙 (⛔ 과거 기록 cascade 삭제 없음 — 불변조건)
| 관계 | 규칙 |
|---|---|
| RiskAssessment의 소유 자식 전부 | cascade(기록 루트가 지워질 때만) |
| SafetyBriefing의 소유 자식 전부 | cascade |
| **Site → RiskAssessmentProgram** | **nullify**(cascade ❌) |
| **RiskAssessmentProgram → RiskAssessment** | **연결 nullify, 평가 독립 생존**(cascade ❌). Program은 물리삭제 대신 `archived` |
| **Site → SafetyBriefing** | **nullify**(cascade ❌) — 표시값 스냅샷으로 생존 |
| 평가/Program → SafetyBriefing | 참조뿐, 삭제 무관 |
| 3년 등 보존기간 | DB 아님 → **앱 레벨 가드**(retainUntil·삭제 UX), 자동 판정 없음 |

## 불변 시점 (lock timing — 교정 #3)
| 엔티티 | 잠금 시점 |
|---|---|
| AssessmentCriteria | 평가 **inProgress 전환** 시 |
| RiskAssessmentItem · RiskAssessmentParticipant | 평가 **finalized** |
| SharingEvent | **생성 즉시** |
| CorrectiveAction | 별도 수명주기 — **finalized 이후에도 수정 가능** |
| BriefingRiskItemSnapshot · 전달내용 | 브리핑 **conducted** |
| BriefingParticipant · 서명 | 브리핑 **finalized** |

## 공유 이력 (교정 #2 — 이중 저장 제거)
- **TBM 방식 공유 = 확정 `SafetyBriefing` 자체**(별도 SharingEvent 생성 안 함 → CloudKit 중복 문제 소멸).
- `SharingEvent` = **교육·게시·서면·전자** 공유만.
- **조회 모듈**이 `SafetyBriefing` + `SharingEvent`를 하나의 통합 공유 이력으로 반환.

## 수명주기
- 평가: `planned · inProgress · finalized · cancelled` + 조치별 상태, `closed`=파생
- TBM: `draft · conducted · finalized · cancelled`

## SCHEMA-V3 동결 입력 = **4개** (교정 #6 — 전부 확정 전 동결 ❌)
1. TestFlight 배포 여부 · 2. Production 스키마 배포 여부 → **스키마 경로(가산 vs 리셋)**
3. 데이터 생성한 것으로 알려진 테스트 사용자 · 4. 로컬 데이터 보존 필요 → **실제 데이터 이관 필요성**

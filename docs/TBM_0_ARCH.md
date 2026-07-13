# TBM-0 v2 — Safety Briefing 도메인 설계 (코드 없음 · SCHEMA-V3 동결용 DRAFT)

> 목적: TBM/Toolbox Briefing 도메인 확정 + 참여자 모델을 LEGAL-2와 함께 잠금. 근거 = [LEGAL_SOURCE_TABLE_KR_US.md](LEGAL_SOURCE_TABLE_KR_US.md) §C.
> 관통 원칙: 기록 도구(판정 아님) · 참석 확인 = "전달받음" 기록(책임포기 아님) · **출처 ID(UUID 추적용) + 값 복사 스냅샷(불변)**, mutable 교차참조 금지.
> 내부명 **Safety Briefing**. 표시: 한국=TBM, 미국=Toolbox Talk/Pre-Task Briefing/Job Briefing(프로필별).

## 1. 관할별 프로필 (주기·용어·**보존** 분리 — 교정 #8)
| 프로필 | 근거 | 주기 | 보존 |
|---|---|---|---|
| 한국 TBM | 고시 2024-76호 | 🟡노력의무 | 위험성평가 공유기록이면 3년(§8) |
| 미국 CA 건설 | 8 CCR 1509 | 🔴10근무일마다 +Code of Safe Practices | 관할/정책별 |
| 미국 전기 | 1926.952 | 🔴작업 전(반복작업 하루/교대 1회) | 관할/정책별 |
| 미국 일반 | 연방 공통 없음 | ⚪권고 | 사업장 정책 |

## 2. `SafetyBriefing` 엔티티 (교정 #6 — 독립 실행 가능)
- **Site 필수 소속**. `Area`·`RiskAssessmentProgram`·`RiskAssessment` 연결 = **선택**(standalone Toolbox Talk 허용).
- 필드: 작업 내용·일시·장소 · 관할 프로필 · 담당자 · 전달내용 · 수명주기 상태(§5).
- **삭제 보호**: 원본 Site/Program/Assessment 삭제가 과거 브리핑을 **cascade 삭제 금지** → 식별자·표시값을 스냅샷 보존(§3·§9).

## 3. `BriefingRiskItemSnapshot` (교정 #3 — Briefing 소유 값 스냅샷)
- 브리핑이 **소유하는 명시적 값 복사**. `sourceAssessmentID`/`sourceItemID` = **출처 추적용 UUID일 뿐**.
- 값 복사: 위험요인 · 위험수준 · 현재조치 · 개선대책 · **표시 문구**. → 원본 삭제·수정과 무관하게 보존.

## 4. `BriefingParticipant` (부모 소유·불변)
- 필드: 이름(필수)·사번/소속/직무(선택)·역할·참석 확인·선택 서명(§6).
- **공유 범위 축소(교정 #4)**: `RiskAssessmentParticipant`와 **`ParticipantRole`·`ConfirmationMethod`만** 공유. **평가의 순회/면담/설문 참여방법은 재사용 금지**(TBM 참석 확인과 별개 개념).

## 5. 수명주기 · 잠금 (교정 #2 — 첫 확인 전체잠금 제거)
```
draft → conducted → finalized  (+ cancelled)
```
- **conducted**: 전달내용 + 위험 스냅샷 **잠금**. 참석 확인은 **계속 가능**.
- **finalized**: 참석자·서명까지 **모두 잠금**.
- 첫 참석 확인 즉시 전체 잠금 규칙 **삭제**.

## 6. 서명 (교정 #7)
- 이벤트가 소유: `signatureData`(선택 **Other User Content**)·`signedAt`·`confirmationMethod`.
- **생체인증·법적 전자서명·위험수락 효력 주장 금지.** 참여·전달 확인일 뿐.

## 7. 정정 기록 (교정 #5 — 중복 아닌 정정)
- 잠긴 브리핑 정정 = **새 기록** + `supersedesBriefingID`·`correctionReason`·`correctedAt`·`correctedBy`로 원본 연결.

## 8. SafetyBriefing ↔ SharingEvent 정본 (교정 #1)
- **`SafetyBriefing`이 원본 기록.** 연결된 위험성평가에 공유 증명이 필요하면 **finalize 시 불변 `SharingEvent` 스냅샷을 같은 저장 단위에서 원자적 생성**.
- `SharingEvent`는 `sourceBriefingID` + 내용 스냅샷만 보유 — **mutable SafetyBriefing 관계 의존 금지**.
- **중복 방지 규칙**: 한 브리핑 finalize당 SharingEvent 최대 1건(재정정 시 §7 supersedes 체인으로).

## 9. 보존기간 (교정 #8)
- **3년 일괄 단정 금지.** 한국 위험성평가 공유기록 / 미국 관할 프로필 / 사업장 정책 분리.
- 앱은 **적용 정책 + `retainUntil` 기록·안내**만. 법적 준수 자동 판정 안 함.

## 10. 개인정보 (교정 #9 — PRIVACY_AUDIT 준용)
- **① ASC**: BriefingParticipant도 private CloudKit only → 기존과 동일 미수집 방어 가능.
- **② PIPA**: 참석자 이름·서명 = 제3자. **사업주가 처리자일 가능성 높음.** 앱 제공자의 수탁자 해당 여부는 **계약·실제 접근/처리 구조에 따라 별도 법률 검토**(단정 금지).

## 11. SCHEMA-V3 반영 항목 (LEGAL-2와 함께 동결)
- [ ] `SafetyBriefing`(Site 필수·나머지 선택) + `BriefingParticipant` + `BriefingRiskItemSnapshot`
- [ ] 공유 enum `ParticipantRole`·`ConfirmationMethod` 추출(모델 공유 아님)
- [ ] SafetyBriefing→SharingEvent 원자적 스냅샷 생성 규칙
- [ ] 삭제 보호(cascade 금지) + 정정 체인(supersedes)

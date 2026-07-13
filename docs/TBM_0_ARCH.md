# TBM-0 — Safety Briefing 도메인 설계 (코드 없음 · SCHEMA-V3 동결용 DRAFT)

> 목적: TBM(작업 전 안전점검회의)/Toolbox Briefing 도메인을 확정해, **참여자 모델을 LEGAL-2와 함께** 잠근다(따로 하면 별도 마이그레이션). 근거 = [LEGAL_SOURCE_TABLE_KR_US.md](LEGAL_SOURCE_TABLE_KR_US.md) §C.
> 원칙: 기록 도구(판정 아님) · **참석 확인 = "전달받음" 기록**(책임포기·안전동의 서명 아님) · 스냅샷 불변 · 소유권 > 마이그레이션 편의.
> 내부 공통명 **Safety Briefing**. 표시: 한국=**TBM**, 미국=**Toolbox Talk / Pre-Task Briefing**.

## 1. 관할별 프로필 (jurisdiction profile — 주기·용어·표시 분리)
| 프로필 | 근거 | 주기 성격 | 표시 |
|---|---|---|---|
| 한국 TBM | 고시 제2024-76호 | 🟡노력의무(중대재해 유해위험요인 상시 주지) | 작업 전 안전점검회의(TBM) |
| 미국 CA 건설 | 8 CCR 1509 | 🔴10근무일마다 + Code of Safe Practices | Tailgate/Toolbox |
| 미국 전기 | 1926.952 | 🔴작업 전(반복작업 하루/교대 1회, 변경 시 추가) | Job Briefing |
| 미국 일반 | 연방 공통 없음 | ⚪권고 | Toolbox Talk |
- 프로필은 §LEGAL-2의 `RiskAssessmentProgram`(현장+관할+업종+적용기간)과 **동일 관할 축** 재사용.

## 2. `SafetyBriefing` 엔티티 (신규)
| 필드군 | 내용 |
|---|---|
| 작업·일시·장소 | 작업 내용 · 일시 · 장소(현장/구역) |
| 관할 프로필 | §1 프로필(주기·용어 결정) |
| **전달내용 스냅샷** | 브리핑에서 전달한 내용을 **불변 스냅샷**(원본 위험성평가·문서가 나중에 바뀌어도 회의록 불변) |
| **위험성평가 연결** | linked 평가의 **당시 상태 스냅샷 참조**(§4) |
| 수정 잠금 시점 | §5 |
| 담당자 | 브리핑 실시자 |

## 3. `BriefingParticipant` (신규 · **브리핑이 소유·불변**)
- LEGAL-2 `RiskAssessmentParticipant`와 **동형** — 이름(필수)·사번/소속/직무(선택)·근로자|대표 구분·참석 확인 방식·**선택 서명**.
- **공통 enum·검증 로직만 공유**(참여방법·확인방식). 각 부모가 소유하는 불변 스냅샷 — 공유 Participant N:M ❌(LEGAL-2 교정 #1과 동일 원칙).
- 법인 직원명부 생기면 선택적 `personId` 연결.

## 4. 위험성평가 스냅샷 연결 (불변)
- 브리핑은 대상 위험성평가의 **브리핑 시점 상태를 스냅샷**(유해위험요인·위험성 수준·개선대책 등)으로 보존.
- 원본 평가가 나중에 수정·재평가돼도 **과거 브리핑 기록은 불변**. (LEGAL-2 `AssessmentCriteria`·`SharingEvent` 스냅샷 원칙과 일관)

## 5. 수정 잠금 시점 (edit-lock)
- **lock 전**: draft — 작업·내용·참석자 수정 가능.
- **lock 시점**: 브리핑 실시 확정(참석 확인 기록 시점) → 이후 **전달내용·참석·서명·평가 스냅샷 모두 불변**.
- 정정이 필요하면 새 브리핑 기록 생성(과거 불변 유지). LEGAL-2 `finalized`와 같은 계약.

## 6. 참석 확인 (책임 프레이밍 금지)
- 참석 확인 = **"브리핑 내용을 전달받음" 기록.** 서명은 선택 증빙. **책임포기·위험수락·안전동의 아님.**
- 확인 방식: 관리자 출석 기록(기본) / 본인 확인 / 서명(선택). LEGAL-2 참여자와 동일 enum.

## 7. 개인정보 (두 축 — PRIVACY_AUDIT 준용)
- **① ASC 수집**: BriefingParticipant도 private CloudKit only → 기존과 **동일 미수집 방어 가능**.
- **② PIPA**: 참석자 이름·서명 = 제3자 정보 → 입력 권한·고지·보존·삭제 책임(앱=도구/수탁). ASC와 별개 축.

## 8. SCHEMA-V3 반영 항목 (LEGAL-2와 함께 동결)
- [ ] `SafetyBriefing` + `BriefingParticipant`(부모 소유·불변) + 위험성평가 스냅샷 참조 방식
- [ ] `RiskAssessmentParticipant` ↔ `BriefingParticipant` 공통 enum/검증 **공유 추출**(중복 로직 방지, 모델 공유 아님)
- [ ] 관할 프로필을 `RiskAssessmentProgram`과 공유 축으로
- [ ] lock/스냅샷 삭제규칙(3년 보존은 앱 레벨 가드)

# LEGAL-2-ARCH — 위험성평가 도메인 설계 (코드 없음 · SCHEMA-V3 승인용 DRAFT)

> 목적: 참여자만 먼저 붙여 V3/V4/V5 연쇄 마이그레이션을 만드는 대신, **평가 수명주기·기준·참여·공유·이행·보존을 하나의 스키마 계약으로** 먼저 확정. 근거 = [LEGAL_SOURCE_TABLE_KR_US.md](LEGAL_SOURCE_TABLE_KR_US.md) (게이트 통과 v3).
> 원칙: 기록 도구(판정 아님) · 누락은 "예정/기록 없음/완료" 사실만 · 서명=참여·전달 확인(책임포기 아님) · 스냅샷 보존(원본 수정돼도 과거 불변).
> **이 문서는 설계만. 승인 후 SCHEMA-V3(모델·관계·삭제규칙·마이그레이션) → 슬라이스 구현.**

## 1. 평가 수명주기 (신규 status 축)
```
예정(planned) → 진행(inProgress) → 평가완료(assessed) → 개선조치(remediation) → 종결(closed)
```
- **예정**: 실시 전 일정 통지(제37조의3 사전 공유)를 이 상태에서. 현재 "완료 시 1회 저장" 구조로는 불가 → 수명주기 필수.
- 각 전이 시각 기록. 종결 = 모든 개선조치 이행·확인 완료.

## 2. 엔티티 지도 (신규 N / 확장 E / 기존 K)

| 엔티티 | 상태 | 소유/관계 | 핵심 필드 |
|---|---|---|---|
| `RiskAssessmentProgram` | **N** | Site 1—N Program | 운영방식(정기/**상시**), 주기, 월간평가·주간공유·TBM연동 설정 |
| `RiskAssessment` | **E** | Program 1—N 평가 | + status(수명주기) + scheduledAt(예정) + 기준스냅샷 ref |
| `AssessmentCriteria` | **N**(스냅샷) | 평가에 임베드/참조 | 위험성 기준·**허용 임계값**·매트릭스를 **평가 시점 스냅샷** |
| `RiskAssessmentItem` | **E** | 평가 1—N 항목 | + **허용/불허용 결정** (기존 likelihood·severity·riskLevel·reductionMeasure·postRiskLevel 유지) |
| `CorrectiveAction` | **N** | 항목 1—N 조치 | 실제 이행 조치·**이행일·확인자·증거(사진)**·개선후위험도·**효과확인** (기존 correctiveActionStatus·dueDate·responsibleName **흡수**, 병렬 중복 금지) |
| `Participant` | **N** | 평가 N—M / TBM 재사용 | 이름(필수)·사번/소속/직무(선택)·근로자·대표 구분·참여방법(순회/면담/설문)·참여시각·확인방식·서명(선택) |
| `WorkerRepStatus` | **N** | 평가 1—1 | 대표 참여 **요청 여부**·참여 여부·대표 식별·참여방법 |
| `SharingEvent` | **N** | 평가 1—N 공유 | 사전/사후 구분·시각·방법(교육·게시·서면·전자·TBM)·대상·담당자·**내용 스냅샷** |

## 3. 기존 필드 매핑 (중복 금지 — 오너 지적)
- `RiskAssessmentItem.postRiskLevel` → `CorrectiveAction.개선후위험도`로 이관/연결(신설 병렬 필드 금지)
- `RiskAssessmentItem.correctiveActionStatus·dueDate·responsibleName` → `CorrectiveAction` 흡수
- `RiskAssessment.assessorName`(단일 문자열) → `Participant`(담당자/평가자 역할)로 승격 검토

## 4. TBM-0 개념 (SCHEMA-V3 공유 — 별도 문서에서 상세)
- TBM 참석자 = **`Participant` 재사용**(평가와 스키마 공유 → 별도 마이그레이션 방지)
- TBM은 **당시 위험성평가 스냅샷** 참조(원본 수정돼도 회의록 불변)
- 참석 확인 = 전달받음 기록(책임포기 아님) · 서명 = 선택 증빙

## 5. 개인정보 (지금 시작 — 오너 지적)
- Apple "collect" = 기기 밖 전송+접근가능. **면제는 on-device only.** CloudKit private DB는 기기 밖 → **"Data Not Collected" 재검증 필요**(개발자 조회 불가만으로 면제 아님).
- 앱은 **이미** 점검자·평가자 이름·현장 주소·사진·자유기록 동기화 → 참여자 추가 이전에 **기존 선언부터** 공식 정의로 재판정.
- 참여자·서명 = **제3자 개인정보** + 한국 PIPA(앱=도구/수탁, 사업주=처리자) → 개인정보처리방침·App Privacy·수집 유형 재작성.
- 산출물: `app_privacy_answers` 재판정 + `privacy_policy` 갱신 + Connect 단일레코드 등록 **전** 반영(결제 트랙 게이트).

## 6. SCHEMA-V3 승인 항목 (다음 게이트)
- [ ] 위 엔티티·관계·**삭제규칙**(cascade vs nullify — 3년 보존과 충돌 주의) 확정
- [ ] V2→V3 마이그레이션 계획(신규 @Model 다수 + 기존 필드 이관) — **선재 SchemaMigration 병렬 플레이크(task_fb1e657c) 감안**
- [ ] `Participant`를 평가·TBM 공유로 둘지, 분리할지
- [ ] `AssessmentCriteria`를 임베드 스냅샷 vs 별도 엔티티

## 7. 구현 슬라이스 (스키마 확정 **후**)
```
2a 평가 계획(수명주기·예정)·참여자    2b 기준·허용가능성 결정
2c 개선조치 이행·개선후위험도          2d 사전/사후 공유 이벤트
2e 3년 보존 경고·삭제·내보내기
TBM-1~4 TBM 구현                      CONTINUOUS 월간·주간·매작업일 TBM 연동(Program 소유)
```

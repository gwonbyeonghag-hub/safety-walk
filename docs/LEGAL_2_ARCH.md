# LEGAL-2-ARCH v2 — 위험성평가 도메인 설계 (코드 없음 · ARCH 방향 승인 / SCHEMA-V3 동결 보류)

> 상태: **ARCH 방향 승인**(오너). SCHEMA-V3 동결·2a 구현은 보류. v2 = 오너 8개 교정 반영. 근거 = [LEGAL_SOURCE_TABLE_KR_US.md](LEGAL_SOURCE_TABLE_KR_US.md)(게이트 통과).
> 관통 원칙: **기록 소유권·불변성 > 마이그레이션 편의** (v1에서 이걸 희생하려다 오너가 차단). 참여·서명·기준은 그 이벤트가 소유하는 **불변 스냅샷**.
> 순서: 개인정보 재판정 → **이 v2 (+ SCHEMA-V3 lock 2건 §2.1·§6)** → TBM-0 → SCHEMA-V3 동결 → 구현.
> ⛔ **명시적 승인 전 `default.store`·CloudKit 환경 초기화 금지. 모델·마이그레이션·UI 코드 금지.**

## 1. 두 개의 독립 수명주기 (교정 #2)
- **평가 상태**: `planned · inProgress · finalized · cancelled` (선형 아님)
- **개선조치 상태**: 각 `CorrectiveAction`이 개별 관리
- **`closed`는 저장 상태가 아니라 파생** — 모든 **필수** 조치의 이행·효과확인 완료 시 계산
- 화면 표시 예: `평가완료 · 개선조치 3건 진행 중`
- `planned` 상태에서 제37조의3 **사전 일정 공유** 지원

### 1.1 "필수 개선조치" 정의 (closed 파생 규칙)
> ⚠️ **"불허용"은 법적 위반 판정이 아님** (교정 #6). = **사용자/사업장이 설정한 허용 기준(임계값) 초과**. 앱은 자동 계산할 뿐, **사용자가 확인**해 확정. 기록 도구이지 판정 도구 아님.
- **허용 기준 초과 항목**은 **최소 1개의 필수 `CorrectiveAction`** 필요.
- **기준 초과 0건 평가**는 필수 조치 없음 → `finalized` 즉시 `closed` 파생 가능.
- **효과확인 완료** = 각 필수 조치가 이행일·확인자 기록 + 효과확인(개선후위험도가 기준 이내 등) 완료.
- `closed` = `finalized` **AND** 모든 필수 조치의 이행·효과확인 완료.

## 2. 엔티티 지도 (N 신규 / E 확장 / K 기존)

| 엔티티 | 상태 | 소유·관계 | 핵심 | 교정 |
|---|---|---|---|---|
| `RiskAssessmentProgram` | N | Site 1—N | 운영방식(정기/상시) + **jurisdiction + industry/profile + effective period** | #4 |
| `RiskAssessment` | E | Program 1—N | + 평가상태(§1) + scheduledAt + **소유 기준 스냅샷** + 근로자대표 필드(§흡수) | #2 #8 |
| `AssessmentCriteria` | N | 평가 **1:1 소유·불변(값 복사)** | 위험성 기준·허용 임계값·매트릭스 = 평가 시점 스냅샷. 공통 가변 엔티티 참조 금지 | #3 |
| `RiskAssessmentItem` | E | 평가 1—N | + **기준 초과 여부**(자동계산+사용자 확인, §1.1) · **`riskLevel: RiskLevel?`(nil=미평가, §2.1)** | §2.1 |
| `CorrectiveAction` | N | 항목 1—N | 실제 조치·이행일·확인자·증거·개선후위험도·효과확인 (기존 status·dueDate·responsibleName·감소대책 **흡수**) | #5 |
| `RiskAssessmentParticipant` | N | **평가가 소유·불변** | 이름(필수)·사번/소속/직무(선택)·근로자|대표·참여방법·시각·확인방식·서명(선택) | #1 |
| `BriefingParticipant` | N | **TBM이 소유·불변**(TBM-0) | 위와 동형. 공통 **enum·검증 로직만** 공유 | #1 |

- **직원명부/`Person` 엔티티 없음** — 법인 기능 전까지. 나중에 선택적 `personId`로 두 참여기록을 연결(교정 #1).
- **근로자대표**(교정 #8): 독립 수명 없음 → 별도 @Model ❌. `RiskAssessment` 필드(대표 참여 요청 여부·참여 여부) + 해당 `RiskAssessmentParticipant`(근로자|대표 구분·식별·참여방법)로 **흡수**.

### 2.1 SCHEMA-V3 lock #1 — 미평가 불변조건 (자동 Low 부활 차단)
- 문제: planned/inProgress를 **영속**하면 현재 `RiskAssessmentItem.riskLevel` 저장기본값 `.low`(CloudKit용으로 LEGAL-0이 남김)가 **미평가를 다시 Low로 저장**. LEGAL-0(생성자만 필수화)은 "미평가는 영속 안 함"에 의존했으므로 무력화됨.
- **우선안**: `riskLevel: RiskLevel?`(nil = 미평가). **CloudKit은 optional 허용** — 오히려 문제의 `.low` 기본값을 제거함. `finalized` 전 **전체 항목 위험도 입력 검증**(미완성이면 finalize 불가).
- **draft-only 대안**과 비교하되, 공통 **불변조건**: *미평가 상태는 절대 Low로 표현/저장되지 않는다.*
- ⚠️ **파급**: 저장필드 optional화 → report·PDF·Mac 소비부가 nil("미평가") 처리 필요(LEGAL-0의 draft 범위보다 넓음).
- ⚠️ **§6과 상호작용**: Production 스키마 배포됐으면 non-optional→optional 변경이 **가산 호환**인지 SCHEMA-V3에서 확인.

## 3. 공유 이벤트
| 엔티티 | 상태 | 소유 | 핵심 |
|---|---|---|---|
| `SharingEvent` | N | 평가 1—N | 사전/사후 구분·시각·방법(교육·게시·서면·전자·TBM)·대상·담당자·**내용 스냅샷**. PDF≠공유증명 |
공유 범위(사후) = 유해위험요인 + 위험성 결정 결과 + 개선대책 + **개선대책 이행 결과**.

## 4. 기존 필드 매핑 + legacy 이관 조건 (교정 #5)
- 흡수: `postRiskLevel`·`correctiveActionStatus`·`dueDate`·`responsibleName`·`reductionMeasure` → `CorrectiveAction`. **병렬 중복 필드 금지.**
- **legacy 이관 조건**: 항목당 최대 1건 `CorrectiveAction` 생성, **오직** 담당자·기한·감소대책·개선후위험도·상태 중 **하나라도 의미 있을 때만**. 기본값 `.notStarted`만인 항목은 조치 생성 안 함(빈 조치 양산 금지). 기준 = [RiskAssessmentItem.swift](SafetyWalkCore/Sources/SafetyWalkCore/RiskAssessmentItem.swift).

## 5. 개인정보 재판정 (교정 #7 — 결론 열어둠, 지금 진행)
- Apple: collect = 기기 밖 전송으로 **개발자/파트너가 지속 접근** 가능. **private CloudKit은 사용자 전용 접근·개발자 포털 미표시** → **미수집 해석도 방어 가능**.
- ⇒ "Data Not Collected가 깨졌다"고 **선결론 금지**. 항목별(이름·주소·사진·사용자콘텐츠·참여자 제3자정보) 공식 정의로 판정, **불확실 항목은 "Apple 공식 문의 필요"로 분리**.
- 산출물: 별도 `PRIVACY_AUDIT.md`(항목별 판정) → `app_privacy_answers`·`privacy_policy` 갱신 여부 결정. 참여자=제3자 정보라 한국 PIPA(앱=도구/수탁) 병기. **Connect 단일레코드 등록 게이트.**

## 6. SCHEMA-V3 lock #2 — 마이그레이션 판단 4확인 (교정 #6)
TestFlight 사용자 유무만으로 결정 ❌. **오너가 확인해야 할 4가지**(Apple 계정 필요 — Claude 불가):
1. 내부/외부 **TestFlight 배포** 여부 (TestFlight = **Production CloudKit** 사용)
2. **CloudKit Production 스키마 배포** 여부
3. Production **보존 레코드** 존재 여부
4. 기존 설치 기기 **로컬 데이터** 보존 필요 여부

**결정 규칙 (CloudKit 하드 제약)**: Production에 배포된 레코드 타입·필드는 **삭제 불가, 변경은 가산만**.
- **①·② 모두 아니오** → 개발 저장소·CloudKit 개발 스키마 리셋 + **V3를 첫 출시 스키마**로(이관 회피).
- **② 예** → **레코드 없어도 가산형 V3**(기존 타입·필드 유지, 신규만 추가). "완전 초기화" 불가.
- **③·④ 예** → 그 위에 실제 데이터 이관 단계 추가.
- ⚠️ 리셋 가능 판정이어도 `~/Library/Application Support/default.store`·CloudKit 초기화는 **오너 명시 승인 후에만**.

## 7. SCHEMA-V3 동결 항목 (다음 게이트 — 아직 동결 안 함)
- [ ] §2 엔티티·관계·**삭제규칙**(cascade vs nullify — 3년 보존은 앱 레벨 가드로) 확정
- [ ] 마이그레이션 vs 리셋 결정(§6)
- [ ] `AssessmentCriteria` 값 복사 방식 확정
- [ ] TBM-0(BriefingParticipant·서명·스냅샷) 반영

## 8. 구현 슬라이스 (SCHEMA-V3 동결 **후**)
```
2a 평가계획(수명주기·예정)·참여자   2b 기준·허용가능성 결정
2c 개선조치 이행·개선후위험도         2d 사전/사후 공유 이벤트
2e 3년 보존 경고·삭제·내보내기
TBM-1~4 TBM 구현                     CONTINUOUS 월간·주간·매작업일 TBM 연동(Program 소유)
```

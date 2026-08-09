# LEGAL-3B — US Federal 점검 템플릿 출처 감사 (WO LEGAL-3B)

> **검토 기준일: 2026-08-09.** 범위: **Federal OSHA만**(29 CFR 1910 General Industry · 29 CFR
> 1926 Construction). State Plan(주 자체 승인 프로그램)·지역/사업장 규정·PPE 인증 워크플로우는
> 이 WO의 범위 밖이다(§7 한계 참조).
> 정본 출처: `[docs/LEGAL_SOURCE_TABLE_KR_US.md](LEGAL_SOURCE_TABLE_KR_US.md)`(B절, 오너 승인
> 2026-07-13)가 앞서 식별한 추락 임계값 분리(1910.28=4ft / 1926.501=6ft)·State Plan 고지 필요성과
> 이번 감사 결과가 일치한다.

## 1. 무엇이 바뀌었나

기존 `checklist_global.json`(`global-general-v1`)은 General Industry와 Construction 기준을
하나의 템플릿·항목에 섞어 담고 있었다 — 가장 뚜렷한 예가 구 `checklist.item.global.fall.001`:

> "Unprotected edges and openings 6 ft or higher protected by guardrails, nets, or personal fall
> arrest (**4 ft in general industry**)"

한 문장 안에 건설(6ft, 29 CFR 1926.501(b)(1))과 일반산업(4ft, 29 CFR 1910.28(b)(1)(i)) 임계값이
동시에 들어 있다 — 사용자가 실제로 어느 기준 아래 있는지 이 항목만으로는 알 수 없다. 이 WO는
**새 스키마를 만들지 않는다** — 대신 `.global`이 반환하는 점검 선택지를 다음 두 개의 **별도**
버전형 템플릿으로 교체했다(§A):

| 템플릿 | id | industryScope | 카테고리 | 항목 | sourceCatalog |
|---|---|---|---|---|---|
| U.S. Federal — General Industry | `us-federal-general-industry-v1` | `general` | 14 | 25 | 29 CFR 1910.* 15건 |
| U.S. Federal — Construction | `us-federal-construction-v1` | `construction` | 13 | 18 | 29 CFR 1926.* 15건 |

`checklist_global.json`(`global-general-v1`)은 **삭제하지 않았다** — 파일·내용·localization
key 그대로 번들에 남아 있고 `ChecklistTemplateLoader.loadTemplate(filename:region:)`으로 여전히
decode된다(Core 테스트로 고정). 다만 `ChecklistTemplateLoader.load(for: .global)`(사용자가 보는
선택 목록)에는 더는 나타나지 않는다 — 과거 `Inspection.templateId == "global-general-v1"` 기록의
카테고리/항목 표시(`Localizable.strings` 조회)는 그대로 작동한다.

## 2. 알려진 혼합 결함 — 해결 증거

| 결함 | 조치 | 근거 |
|---|---|---|
| 일반산업/건설 추락 기준 혼합 | 완전 분리 — GI는 `checklist.item.usGeneral.wws.001`(4ft, 1910.28(b)(1)(i)), Construction은 `checklist.item.usConstruction.fall.001`(6ft, 1926.501(b)(1)). 두 템플릿의 `sourceCatalog`는 서로소(GI=1910.* only, Construction=1926.* only) — Core 테스트 `generalIndustryAndConstructionCatalogsNeverCrossCiteEachOther`가 회귀를 막는다. | 1910.28(b)(1)(i) · 1926.501(b)(1) |
| 건설 임시배선 GFCI/AEGCP 대안 누락 | 신규 `checklist.item.usConstruction.elec.002` — GFCI **또는** AEGCP 중 사업주가 선택할 수 있다는 원문 그대로("...or does the employer use an Assured Equipment Grounding Conductor Program"), 하나만 강제하지 않는다. | 1926.404(b)(1)(i)-(iii) |
| 단순화된 전기 접근거리 문구 | 구 `checklist.item.global.elec.001`-`003`는 코드/케이블 손상·GFCI·패널 여유공간만 다루고 "접근거리" 자체가 없었다(재검토 결과 실질적 접근거리 문구는 애초 없었음). 신규 GI `checklist.item.usGeneral.elec.002`는 자격/비자격자 구분 + "비자격자는 1910.333(c)(3)에 정한 최소 이격 거리" 로 조건부 인용하고, **표(Table S-5)의 전압별 수치를 항목 문구에 통째로 베끼지 않았다** — prompt이지 규정 전문 복제가 아니라는 원칙(§C 서두) 준수. Construction 쪽은 1926.416이 자격/비자격 구분 자체를 두지 않아(§4 확인) 접근거리 관련 문구를 넣지 않았다(근거 없는 항목을 만들지 않음). | 1910.333(c)(2)-(3) · 1926.416 |
| 호흡보호구 프로그램 적용조건 | 신규 GI `checklist.item.usGeneral.resp.001`-`002`, Construction `checklist.item.usConstruction.resp.001` 모두 "Where respirators are necessary/required"로 시작 — 1910.134(a)/(c)(1)이 전 사업장이 아니라 호흡보호구가 필요한 경우에만 프로그램을 요구한다는 원문 조건을 그대로 반영했다(구 항목은 "provided and worn where airborne hazards are present"로 이미 조건부였으나, 신규 항목은 조문 번호를 명시해 추적 가능하게 했다). | 1910.134(a)(2), (c)(1) |

## 3. 범위 이동/제거 판단 (기존 17-카테고리 대비)

| 구 카테고리 | 신규 GI | 신규 Construction | 판단 | 근거 |
|---|---|---|---|---|
| commonSafety(일반 안전) | 제거 | 제거 | 공식 표준 번호로 특정할 수 없는 범용 문구(오리엔테이션 등) — 근거 없는 항목은 만들지 않는다는 원칙(§B)에 따라 제거. JHA 관련 안내는 이미 앱의 위험성평가 모듈(RiskAssessment/JHA)에 있다. | — |
| housekeeping | 유지(축소) | 유지(축소) | 1910.22 / 1926.25로 각각 재작성. | 1910.22(a) · 1926.25(a) |
| walkingWorkingSurfaces | 유지(4ft로 명확화) | fallRisk로 이동 | GI는 1910.28(walking-working surfaces가 표준 제목 그대로), Construction은 1926.501(fall protection)이 표준 제목이라 카테고리명을 그 축에 맞춰 배치. | 1910.28 · 1926.501 |
| fallRisk | (wws 참고) | 유지(6ft) | 위 §2 참고. | 1926.501(b) |
| laddersScaffolds | 사다리만 유지 | 사다리+비계 유지 | 일반산업은 1926.451 같은 별도 대형 비계 표준이 없어(현장 실무상 비계는 건설 위주) 사다리(1910.23)만 남겼다. | 1910.23 · 1926.1053 · 1926.451 |
| ppe | 유지 | 유지 | 1910.132(hazard assessment 포함) / 1926.95(무상 제공). | 1910.132(d) · 1926.95 |
| respiratoryProtection | 유지(조건부) | 유지(조건부, 1926.103 경유) | §2 참고. | 1910.134 · 1926.103 |
| hazardCommunication | 유지 | 유지(1926.59 경유) | — | 1910.1200 · 1926.59 |
| chemical | **제거** | **제거** | "화학물질 보관·2차방류조" 등 구 항목에 대응하는 단일 표준 번호를 이번 조사에서 확정하지 못했다(HazCom(1910.1200)과 범위가 겹치는 부분은 흡수, 나머지는 공식 근거 미확보로 제거) — 정확히 뒷받침되지 않는 항목은 제거한다는 원칙(§B) 그대로. | — |
| electrical | 유지(범위 명확화) | 유지(범위 명확화) | §2 참고. | 1910.303/.333 · 1926.404/.416 |
| lockoutTagout | 유지(포괄) | **범위 축소**(전기 회로만) | Construction에는 1910.147과 동급인 다중 에너지원 LOTO 표준이 없다(§4 확인) — 그대로 두면 근거 없이 포괄 LOTO를 주장하는 셈이라, 1926.417(전기회로 lockout/tagging)로 정확히 좁혔다. | 1910.147 · 1926.417 |
| machineGuarding | 유지 | **handPowerTools로 대체**(신규 카테고리) | 1910.212(Subpart O, 고정식 기계 방호)는 건설에 적용되지 않는다 — 건설의 대응 표준은 1926.300(수공구·동력공구)이라 카테고리 자체를 바꿨다. | 1910.212 · 1926.300 |
| fire | 유지 | 유지 | 1910.157(소화기) / 1926.150(화재예방 프로그램). | 1910.157 · 1926.150 |
| hotWork | 유지 | 유지 | 1910.252 / 1926.352 — 이격거리·화재감시자 조건을 조문 그대로. | 1910.252 · 1926.352 |
| poweredIndustrialTrucks | 유지 | 유지(1926.602(d) 경유) | — | 1910.178(l) · 1926.602(d) |
| confinedSpace | 유지 | **제거** | 1910.146(a)이 **명시적으로 건설을 제외**한다("이 기준은 일반산업의... 건설·조선·농업은 제외") — 건설 전용 밀폐공간 표준(1926 Subpart AA)은 이번 조사 범위에서 다루지 않아, 근거 없는 건설 밀폐공간 항목을 만들지 않고 제거했다. | 1910.146(a) |
| emergencyResponse/emergencyActionPlan | 유지 | 유지 | 1910.38 / 1926.35. | 1910.38 · 1926.35 |

## 4. Prompt별 출처표 — U.S. Federal General Industry (`us-federal-general-industry-v1`)

| item ID | localization key | 적용 조건 | 표준 번호 | source ID / URL | 판단 | 근거 |
|---|---|---|---|---|---|---|
| usgi-house-001 | checklist.item.usGeneral.house.001 | 상시 | 1910.22(a) | src-1910-22 / osha.gov/.../1910.22 | 신규 | 정리정돈 일반 요구사항 |
| usgi-wws-001 | checklist.item.usGeneral.wws.001 | 4ft 이상 개방 측면/모서리 | 1910.28(b)(1)(i) | src-1910-28 / osha.gov/.../1910.28 | 신규 | 구 fall.001에서 GI 임계값만 분리 |
| usgi-wws-002 | checklist.item.usGeneral.wws.002 | 4ft 이상 개구부 | 1910.28(b)(3)(i) | src-1910-28 | 신규 | 상동 |
| usgi-ladder-001 | checklist.item.usGeneral.ladder.001 | 출입용 이동식 사다리 | 1910.23(c)(11) | src-1910-23 | 신규 | 구 ladder.002를 조문 번호로 정밀화 |
| usgi-ladder-002 | checklist.item.usGeneral.ladder.002 | 상시(사다리 사용 시) | 1910.23(b)(11)-(12) | src-1910-23 | 신규 | 3점지지 요건 명문화 |
| usgi-ppe-001 | checklist.item.usGeneral.ppe.001 | 상시 | 1910.132(d)(1) | src-1910-132 | 신규 | 유해요인평가 의무 |
| usgi-ppe-002 | checklist.item.usGeneral.ppe.002 | 상시 | 1910.132(d)(2) | src-1910-132 | 신규 | 서면 인증 요건(PPE 착용자 인증이 아니라 사업주의 평가서 인증 — §6 참고) |
| usgi-resp-001 | checklist.item.usGeneral.resp.001 | 호흡보호구 필요/요구 시 | 1910.134(c)(1) | src-1910-134 | 신규 | §2 조건부 명시 |
| usgi-resp-002 | checklist.item.usGeneral.resp.002 | 호흡보호구 사용 시 | 1910.134(e), (f) | src-1910-134 | 신규 | 의학평가·밀착검사 |
| usgi-hazcom-001 | checklist.item.usGeneral.hazcom.001 | 상시 | 1910.1200(e) | src-1910-1200 | 신규 | 서면 프로그램 |
| usgi-hazcom-002 | checklist.item.usGeneral.hazcom.002 | 상시 | 1910.1200(f) | src-1910-1200 | 신규 | 라벨링 |
| usgi-hazcom-003 | checklist.item.usGeneral.hazcom.003 | 상시 | 1910.1200(g) | src-1910-1200 | 신규 | SDS 접근성 |
| usgi-loto-001 | checklist.item.usGeneral.loto.001 | 정비/보수(예기치 못한 기동 위험) | 1910.147(c)(1) | src-1910-147 | 신규 | 에너지 제어 절차 |
| usgi-loto-002 | checklist.item.usGeneral.loto.002 | LOTO 수행 시 | 1910.147(c)(8) | src-1910-147 | 신규 | 승인된 근로자만 |
| usgi-guard-001 | checklist.item.usGeneral.guard.001 | 상시 | 1910.212(a)(1) | src-1910-212 | 신규 | 협착점 등 방호 |
| usgi-elec-001 | checklist.item.usGeneral.elec.001 | 상시 | 1910.303(g)(1) | src-1910-303 | 신규 | 작업공간 확보 |
| usgi-elec-002 | checklist.item.usGeneral.elec.002 | 충전부 근접작업 | 1910.333(c)(2)-(3) | src-1910-333 | 신규 | §2 참고 |
| usgi-pit-001 | checklist.item.usGeneral.pit.001 | 동력산업차량 운전 | 1910.178(l) | src-1910-178 | 신규 | 교육·평가 이수자만 |
| usgi-conf-001 | checklist.item.usGeneral.conf.001 | 허가대상 밀폐공간 존재 시 | 1910.146(c)(3)-(4) | src-1910-146 | 신규 | 조건부 명시 |
| usgi-fire-001 | checklist.item.usGeneral.fire.001 | 상시 | 1910.157(c)(1) | src-1910-157 | 신규 | 소화기 배치 |
| usgi-fire-002 | checklist.item.usGeneral.fire.002 | 소화기 제공 시 | 1910.157(g)(1) | src-1910-157 | 신규 | 조건부 교육 |
| usgi-hotwork-001 | checklist.item.usGeneral.hotwork.001 | 용접/절단 시 | 1910.252(a)(2)(vii), (xv) | src-1910-252 | 신규 | 화재안전구역 |
| usgi-hotwork-002 | checklist.item.usGeneral.hotwork.002 | 요건 해당 시(35ft 이내 가연물 등) | 1910.252(a)(2)(iii) | src-1910-252 | 신규 | 화재감시자 |
| usgi-eap-001 | checklist.item.usGeneral.eap.001 | OSHA 기준이 요구하는 경우 | 1910.38(a), (c) | src-1910-38 | 신규 | 조건부 명시(§6 참고) |
| usgi-eap-002 | checklist.item.usGeneral.eap.002 | 상시 | 1910.38(d) | src-1910-38 | 신규 | 경보체계 |

## 5. Prompt별 출처표 — U.S. Federal Construction (`us-federal-construction-v1`)

| item ID | localization key | 적용 조건 | 표준 번호 | source ID / URL | 판단 | 근거 |
|---|---|---|---|---|---|---|
| usc-house-001 | checklist.item.usConstruction.house.001 | 상시 | 1926.25(a) | src-1926-25 | 신규 | 잔재물 제거 |
| usc-fall-001 | checklist.item.usConstruction.fall.001 | 6ft 이상 개방 측면/모서리 | 1926.501(b)(1) | src-1926-501 | 신규 | 구 fall.001에서 Construction 임계값만 분리 |
| usc-fall-002 | checklist.item.usConstruction.fall.002 | 6ft 이상 개구부/선단부/경사로 | 1926.501(b)(2), (4), (6) | src-1926-501 | 신규 | 상동 |
| usc-ladder-001 | checklist.item.usConstruction.ladder.001 | 이동식 사다리 사용 시 | 1926.1053(b)(1) | src-1926-1053 | 신규 | 착지면 연장 |
| usc-scaffold-001 | checklist.item.usConstruction.scaffold.001 | 비계 설계 시 | 1926.451(a)(1), (a)(6) | src-1926-451 | 신규 | 하중 4배·유자격 설계 |
| usc-scaffold-002 | checklist.item.usConstruction.scaffold.002 | 비계 사용 중 | 1926.451(f)(3) | src-1926-451 | 신규 | 매 교대 전 점검 |
| usc-ppe-001 | checklist.item.usConstruction.ppe.001 | 상시 | 1926.95(a), (d)(1) | src-1926-95 | 신규 | 무상 제공 |
| usc-resp-001 | checklist.item.usConstruction.resp.001 | 호흡보호구 필요/요구 시 | 1926.103 → 1910.134 | src-1926-103 | 신규 | 준용 조문 명시 |
| usc-hazcom-001 | checklist.item.usConstruction.hazcom.001 | 상시 | 1926.59 → 1910.1200 | src-1926-59 | 신규 | 준용 조문 명시 |
| usc-tools-001 | checklist.item.usConstruction.tools.001 | 가드 장착 가능한 동력공구 | 1926.300(b)(1) | src-1926-300 | 신규 | §3 machineGuarding→handPowerTools 대체 |
| usc-elec-001 | checklist.item.usConstruction.elec.001 | 상시 | 1926.416(a)(1) | src-1926-416 | 신규 | 충전 제거/접지/방호 |
| usc-elec-002 | checklist.item.usConstruction.elec.002 | 임시배선(125V 15/20/30A) | 1926.404(b)(1) | src-1926-404 | 신규 | §2 GFCI/AEGCP 대안 |
| usc-loto-001 | checklist.item.usConstruction.loto.001 | 전기회로 작업 시 | 1926.417(a)-(b) | src-1926-417 | 신규 | §3 범위 축소(전기 한정) |
| usc-pit-001 | checklist.item.usConstruction.pit.001 | 동력산업차량 운전 | 1926.602(d) → 1910.178(l) | src-1926-602 | 신규 | 준용 조문 명시 |
| usc-fire-001 | checklist.item.usConstruction.fire.001 | 상시 | 1926.150(a)(1) | src-1926-150 | 신규 | 화재예방 프로그램 |
| usc-hotwork-001 | checklist.item.usConstruction.hotwork.001 | 용접/절단/가열 시 | 1926.352(a)-(b) | src-1926-352 | 신규 | 가연물 이동/차단 |
| usc-hotwork-002 | checklist.item.usConstruction.hotwork.002 | 상동 | 1926.352(d)-(e) | src-1926-352 | 신규 | 화재감시자·소화장비 |
| usc-eap-001 | checklist.item.usConstruction.eap.001 | 상시 | 1926.35(b)-(c) | src-1926-35 | 신규 | 서면 비상조치계획 |

## 6. Regulation vs. Guidance 구분

이 감사가 인용한 모든 항목은 **29 CFR(연방 규정)** 조문이다 — 법적 구속력 있는 규정(🔴, `LEGAL_SOURCE_TABLE_KR_US.md` 범례 기준)이다. 예외:

- **OSHA Publication 3071 (Job Hazard Analysis)** — 이 WO는 신규 체크리스트 항목의 근거로 3071을
  **인용하지 않았다**(JHA 필드 자체는 §F에서 기존 구현을 감사했을 뿐 3071 기반 신규 항목을 만들지
  않음). 3071은 OSHA 스스로 "권장 Safety and Health Program Management Guidelines"라 명시한
  **자발적 준수지원(compliance assistance) 자료이지 강제 규정이 아니다** — JHA를 "연례 의무"나
  보편적 법정 의무처럼 표현해서는 안 된다는 원칙을 지켰다(`ra.jsa` 관련 화면·리포트에 "매년
  반드시" 류 문구 없음, 기존 화면 문구 무변경 확인).
- **1926.59 / 1926.103 / 1926.602(d)** 는 규정이지만 **다른 규정을 그대로 준용**하는 조문이다 —
  해당 위치의 감사 표에 "→"로 원 조문을 명시해, 준용 관계를 숨기지 않았다.

## 7. 한계

- **시작용 점검표이며 exhaustive checklist가 아니다.** 위 43개 항목(GI 25 + Construction 18)은
  각 표준의 핵심 요구사항 일부만 다룬다 — 예를 들어 1910.147은 (c)(1)/(c)(8) 두 항만 인용했지만
  전체 조문은 훈련·정기점검(periodic inspection) 등 더 많은 하위 조항을 포함한다.
- **State Plan 미반영.** 22개 주(+7개 공공부문 전용, 총 29개 프로그램)가 연방보다 같거나 더
  엄격한 자체 기준을 운영한다(osha.gov/stateplans). 이 앱은 주별 기준 데이터베이스나 위치 기반
  관할 자동판정을 구현하지 않는다(§G 명시 제외) — Federal/State Plan 경고(§E)로 사용자에게
  "이 현장에 적용되는 기준을 확인하라"고 안내할 뿐이다.
- **지역·사업장 규정 미반영.** 시(市)·카운티 조례, 개별 사업장 안전수칙은 이 템플릿에 없다.
- 위 43개 항목의 EN/KO 문구는 원문 규정을 정확히 의역한 것이며, 조문 원문의 장문 인용이 아니다
  — 그러나 의역 과정에서 발생할 수 있는 뉘앙스 손실 가능성은 남아 있다.

## 8. 검증 상태 — 정직 기록

이 감사는 **공식 OSHA/eCFR 원문 대조 기반의 내부 제품 검증**이다. 아래를 명확히 한다:

- 인용된 모든 표준 번호·조문 텍스트는 osha.gov의 해당 standardnumber 페이지를 직접 조회해
  확인했다(§ URL 열 참고). 블로그·컨설팅사·검색요약·AI 사전지식을 근거로 사용하지 않았다.
- **외부 미국 EHS(환경보건안전) 전문가 또는 변호사의 검토는 이뤄지지 않았다.** "법률 검토 완료"
  또는 "OSHA 준수(compliant)"라고 주장하지 않는다 — 이 앱은 준수 여부를 판정하지 않는다
  (CLAUDE.md "No legal judgment").
- 검토 기준일(2026-08-09) 이후 표준이 개정되면 이 문서와 템플릿의 `reviewedOn` 값은 갱신이
  필요하다 — 자동 갱신 메커니즘은 없다.

## 9. JHA 필드 감사 — OSHA 3071 개념 ↔ 기존 구현 (WO LEGAL-3B §F)

기존 구조가 이미 OSHA 3071(Job Hazard Analysis, 자발적 준수지원 가이드 — §6 참고)의 핵심 개념을
충족한다. **새 스키마·필드를 만들지 않았다** — 아래는 감사 결과이지 변경 목록이 아니다.

| OSHA 3071 개념 | 기존 구현 | 증거(테스트/코드) |
|---|---|---|
| Job location | `RiskAssessment.siteName` | `JHAReport.headerGrid` — `raSite` |
| Analyst | `RiskAssessment.assessorName` | `JHAReport.headerGrid` — `raAssessor` |
| Date | `RiskAssessment.assessedAt ?? createdAt` | `JHAReport.headerGrid` — `commonDone` |
| Ordered job steps | `RiskAssessmentItem.sortOrder`(JSA 기법) | `RiskAssessmentItemTests`(WO-2b) — sortOrder 보존 |
| Hazard description | `RiskAssessmentItem.hazardDescription` | 리포트 `cell()` 렌더 |
| Existing/current controls | `RiskAssessmentItem.currentControls` | `JHAReport.controlsCell(label: raItemCurrentControls)` — "현재 안전조치" 라벨로 권고와 구분(WO LEGAL-2c) |
| Recommended controls | `CorrectiveAction.measure`(항목당 1:N) | `JHAReport.controlsCell(label: raItemReduction)` — "감소대책" 라벨, `testJHAReportLabelsCurrentControlsAndReductionMeasureRows`·`testJHAReportPreservesEveryActionAcrossPages`(기존 통과 테스트, 재작성 없음) |

**현재/권고 통제 구분**: 같은 Controls 컬럼을 공유하지만 매 행에 `controlsLabel`(현재 안전조치/
감소대책)을 붙여 페이지 중간에서 봐도 구분된다(`JHAReport.rowBlocks`/`row` 함수, 기존 구현,
WO LEGAL-2c 5차 P1 — 위 두 기존 테스트가 이미 고정).

**1:N 개선조치 유실 방지**: 항목당 여러 개선조치가 있어도 각각 별도 페이지-배치 가능 블록으로
나오고 페이지 경계에서 부모 항목 식별자(작업단계·유해요인)가 반복돼 유실되지 않는다 —
기존 `testJHAReportPreservesEveryActionAcrossPages`(변경 없음)가 이미 고정.

**위험도**: `RiskAssessmentItem.riskLevel`은 앱의 평가 기록(빈도×강도 또는 3단계 직접 입력)이며,
OSHA가 요구하는 인증값이 아니다 — 화면·리포트 어디에도 "OSHA 인증 위험도" 같은 표현이 없다(§6
법적 판정 문구 금지 원칙과 동일).

**추가하지 않은 것(§G 명시 제외 확인)**: 새 assessment 필드·서명 필드·승인 필드 없음. PPE
hazard-assessment 인증(서명·인증일·인증 상태)도 만들지 않았다 — 위 §4 GI PPE 항목(`usgi-ppe-002`)은
"평가가 서면 인증 형태로 기록됐는가?"를 **prompt로 묻는 체크리스트 항목일 뿐**, 인증 워크플로우
(서명·인증일 입력 UI)가 아니다.

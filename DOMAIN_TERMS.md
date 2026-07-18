# DOMAIN_TERMS.md — SafetyWalk / 현장안전 지킴이

## Purpose

This document defines the canonical terminology used in the app, in code, and in documentation.
Terms are listed in English (code-canonical) and Korean (UI display, KO locale).
Use these names consistently — do not invent synonyms.

---

## Core Domain Terms

| English (code/EN UI) | Korean (KO UI) | Definition |
|---|---|---|
| Inspection | 점검 | A structured walkthrough of a site using a checklist. Has a start time, end time, site, area, inspector, and a set of checklist items. |
| Hazard | 위험요인 | An identified unsafe condition or act. Has a photo, type, risk level, location, description, and corrective action status. |
| Site | 현장 | A physical location (e.g. construction site, factory). A site has a name, optional address, and a list of areas. |
| Area | 구역 | A sub-zone within a site (e.g. "1층 전기실", "Electrical Room B"). Can be saved or entered as free text. |
| Inspector | 점검자 | The person conducting the inspection. Name is stored with each inspection record. |
| Checklist | 점검표 | A template-driven list of items to evaluate during an inspection. |
| Checklist Item | 점검 항목 | A single evaluable item in a checklist. Has a title, category, result, optional photo, and optional note. |
| Checklist Template | 점검표 템플릿 | A reusable checklist definition loaded from JSON. Associated with a region profile. |
| Result | 결과 | The outcome of evaluating a checklist item: Pass, Fail, or N-A. |
| Pass | 적합 | Checklist item meets the safety requirement. |
| Fail | 부적합 | Checklist item does not meet the requirement. May trigger hazard registration. |
| N-A | 해당없음 | Checklist item is not applicable to this site or area. |
| Risk Level | 위험 등급 | Severity classification of a hazard: Low, Medium, or High. |
| Low | 낮음 | Hazard poses minimal immediate risk. Color: yellow. |
| Medium | 보통 | Hazard poses moderate risk. Color: orange. |
| High | 높음 | Hazard poses serious or immediate risk. Color: red. |
| Corrective Action | 시정 조치 | The remediation action required to address a hazard. |
| Corrective Action Status | 시정 조치 상태 | Current state of the corrective action: Not Started, In Progress, or Completed. |
| Corrective Action (위험성평가) | 개선조치 | The `CorrectiveAction` model — 1:N remediation actions under a risk-assessment item (measure·담당·기한·상태·이행일·개선 후 위험성·효과확인). Owner-decided term in LEGAL_2_ARCH; distinct from a Hazard's 시정 조치. |
| Effectiveness Result | 효과확인 결과 | The user's record of an 개선조치's effect: Effective (효과 있음) / Partially Effective (부분 효과) / Ineffective (효과 없음). A record, not a legal judgment. |
| Not Started | 미착수 | No corrective action has been taken yet. Default state. |
| In Progress | 진행중 | Corrective action is underway. |
| Completed | 완료 | Corrective action has been finished. |
| Evidence Photo | 증거 사진 | A photo taken to document a hazard or checklist item result. |
| Region Profile | 지역 프로파일 | A configuration set that controls the default checklist template and reference text. Values: Korea, Global. **Selected implicitly by the Language toggle** (한국어 → Korea, English → Global) — it is no longer a separate user-facing control. Korea = KOSHA-oriented template; **Global = U.S. / OSHA-oriented site-inspection template (imperial units)**. |
| Disclaimer | 면책 고지 | Legal notice that the app does not provide compliance determinations. Required on all exports and in Settings. |

---

## Risk Assessment Terms (위험성평가) — v2 WO-2

A formal risk-assessment record, separate from an Inspection (Pass/Fail/NA) and from
ad-hoc Hazard logging. The app **records/reminds only — it does not make legal
determinations** (disclaimer required, see Legal section).

| English (code/EN UI) | Korean (KO UI) | Definition |
|---|---|---|
| Risk Assessment | 위험성평가 | One assessment record (평가표). Holds kind, method, site, assessor, date, and items. Code: `RiskAssessment`. |
| Risk Assessment Item | 위험성평가 항목 | One row of an assessment: task/process, hazard, current controls, risk inputs/level, and the 기준 이내/초과 decision. Owns its 개선조치 as a **1:N `CorrectiveAction` relationship** — it does **not** store reduction measure, post-measure risk, responsible, due date, or status itself (absorbed into `CorrectiveAction`, SCHEMA_V3 §4). Code: `RiskAssessmentItem`. |
| Assessment Kind | 평가종류 | When the assessment is performed: Initial / Regular / Occasional. Code: `RiskAssessmentKind { initial, regular, occasional }`. |
| Assessment Method | 평가기법 | The 4 methods (AD-3). Code: `RiskAssessmentMethod { threeLevel, frequencySeverity, checklist, jsa }`. `usesFrequencySeverity` classifies the risk input: likelihood×severity (`frequencySeverity`, `jsa`) vs. direct 상/중/하 (`threeLevel`, `checklist`). |
| Checklist method | 체크리스트법 | Method that seeds assessment items from a completed Inspection's **failed (부적합)** checklist items (text-copied); risk entered as 3-level. Reuses `linkedInspectionId` / `linkedHazardId`. |
| JSA / JHA | JSA/JHA | Job Safety/Hazard Analysis (overseas/US, Global profile): **ordered** job steps → hazard → controls → risk (frequency×severity). Order kept via `RiskAssessmentItem.sortOrder`. |
| Job Step | 작업 단계 | One ordered step of a JSA. Stored in `RiskAssessmentItem.taskDescription`, ordered by `sortOrder`. |
| Likelihood | 가능성 (빈도) | Frequency×Severity input, 1–3. Code: `likelihood`. |
| Severity | 중대성 (강도) | Frequency×Severity input, 1–3. Code: `severity`. |
| Risk Score | 위험성 점수 | likelihood × severity (1–9). Derived, not stored on its own. |
| Risk Level (band) | 위험성 수준 | Resolved 상/중/하 — **reuses `RiskLevel`**. For 3-Level the user picks it directly; for Frequency × Severity it is derived from the score via `RiskMatrixConfig.band(forScore:)`. |
| Reduction Measure | 감소대책 | Risk-reduction action recorded for an item. Stored on the 개선조치: `CorrectiveAction.measure`. (`DraftItem.reductionMeasure` in the create screen is a transient input value, not a persisted model field.) |
| Post-measure Risk | 개선 후 위험성 | The risk level recorded after a 개선조치 has been implemented. Stored on the 개선조치: `CorrectiveAction.postRiskLevel`. |

The 3×3 (and future 5×5) band boundaries live in **data** (`RiskMatrixConfig`, not
hard-coded `if`): score ≤2 → 하(low), 3–4 → 중(medium), ≥6 → 상(high).

---

## Sharing Terms (공유 기록) — v2 WO LEGAL-2d

A **record of sharing the user performed**. The app never verifies that delivery actually
happened, and never states legal compliance — it records the fact the user reports.

| English (code/EN UI) | Korean (KO UI) | Definition |
|---|---|---|
| Sharing Event | 공유 기록 | One non-TBM sharing of an assessment: phase, method, time, target, owner, and an immutable content snapshot. **Immutable the moment it is created** — there is no edit or delete operation; a correction is a *new* record. Multiple real shares are legitimate, so nothing dedupes them. Code: `SharingEvent`. |
| Sharing Phase | 공유 시점 | Before (사전) = the schedule; after (사후) = the results. Decided by the entry point, never flipped by the user. Code: `SharingPhase { pre, post }`. |
| Sharing Method | 공유 방법 | How the sharing was carried out — **non-TBM only**. TBM sharing is proved by the `SafetyBriefing` itself, never by a `SharingEvent` (LEGAL_2_ARCH §3). Code: `SharingMethod { education, posting, written, electronic }`. |
| Content Snapshot | 공유 내용 스냅샷 | The versioned JSON value-copy of what was shared, stored in `SharingEvent.contentSnapshot`. Enums as raw codes, all dates normalised to UTC whole seconds, deterministic ordering, sorted keys. Excludes evidence photos and participant personal data. Decode failure is **fail-closed** — the app shows an error, never today's data. Code: `SharingSnapshot` (`formatVersion` 1). |
| Current sharing record | 현재 유효한 공유 기록 | A record that is **complete** (phase/method/time present; target, owner, snapshot non-blank and decodable; owned by this assessment; snapshot's assessmentId and phase agree with the event) **and matches the assessment's present state**. Single source: `SharingEventPolicy.isCurrent`. |
| Stale sharing record | 현재 내용과 다른 공유 기록 | A past record that is no longer *current* — the schedule, risk decision, or corrective actions changed after it was made (or the record is incomplete/corrupt). **Stale is not deletion**: the record stays in the history as evidence of what was shared at the time. It simply does not count as sharing of the present state. |

**공유 게이트는 법적 판정이 아니다.** Where a KR-jurisdiction assessment requires a current
pre-/post-sharing record before 시작·확정·종결, that is a **workflow record-completeness gate**
("the record this workflow requires is not there yet"), *not* a determination that the user is
compliant or in violation. The app states facts about its own records only.

---

## Hazard Types

| English | Korean | Notes |
|---|---|---|
| Fall Risk | 추락 위험 | Includes fall from height, trip hazards |
| Electrical | 전기 위험 | Exposed wiring, overloading, improper grounding |
| Fire | 화재 위험 | Flammable materials, fire exits, extinguishers |
| Chemical | 화학물질 위험 | Hazardous substances, improper storage |
| General | 일반 위험 | Does not fit other categories |
| Other | 기타 | User-specified type; requires description |

---

## Data Model Names (Swift code)

These names are used exactly in Swift source. Do not rename without updating this doc.

```
Site
Area
Inspection
ChecklistItem
ChecklistTemplate
ChecklistTemplateItem
ChecklistCategory
Hazard
HazardType
RiskLevel
CorrectiveActionStatus
ChecklistItemResult
RegionProfile
InspectionStatus
RiskAssessment
RiskAssessmentItem
RiskAssessmentKind
RiskAssessmentMethod
RiskMatrixConfig
```

---

## Status Enums

```swift
enum ChecklistItemResult { case pass, fail, notApplicable, unchecked }
enum RiskLevel           { case low, medium, high }
enum CorrectiveActionStatus { case notStarted, inProgress, completed }
enum InspectionStatus    { case inProgress, completed }
enum HazardType          { case fallRisk, electrical, fire, chemical, general, other }
enum RiskAssessmentKind   { case initial, regular, occasional }
enum RiskAssessmentMethod { case threeLevel, frequencySeverity, checklist, jsa }
enum AssessmentStatus    { case planned, inProgress, finalized, cancelled }
enum SharingPhase        { case pre, post }                                   // nil = 미설정
enum SharingMethod       { case education, posting, written, electronic }     // 비TBM 전용
```

### ⚠️ `RegionProfile` 과 `JurisdictionCode` 는 **별개의 축** — 혼용 금지

```swift
enum RegionProfile     { case korea, global }   // 언어·지역 프로파일 (표시·템플릿 선택)
enum JurisdictionCode  { case kr, us }          // 법적 관할 (평가에 값 스냅샷으로 저장)
```

- **`RegionProfile`** 은 어떤 체크리스트 템플릿·문구를 보여줄지 고르는 **표시/콘텐츠 축**이다.
- **`JurisdictionCode`** 는 그 평가에 **어떤 관할의 기록 요건**이 적용되는지를 뜻하는 **법적 축**이며,
  `RiskAssessment.jurisdictionSnapshot` 에 **값 스냅샷**으로 저장된다(나중에 프로그램 설정이 바뀌어도
  과거 평가는 당시 관할을 유지).
- 둘은 서로를 유도하지 않는다. Korea 프로파일이 곧 KR 관할을 의미하지 않으며, 그 반대도 아니다 —
  프로파일은 **기본값을 제안**할 수 있을 뿐 사용자가 확인해야 한다(LEGAL-2d-PATH).
- **`jurisdictionSnapshot == nil` 은 "관할 미설정"** 이며, 어떤 관할의 요건 충족도 주장하지 않는다
  (fail-closed 표시). 코드: `SharingEventPolicy.JurisdictionState { kr, us, unset }`.

---

## Legal / Regulatory Term Handling

| Term | Handling |
|---|---|
| 위험성 평가 (Risk Assessment) | A first-class module (v2 WO-2): a recorded assessment of likelihood/severity or direct level. The app **records** the user's inputs and **does not determine** legal compliance. Risk levels/scores and reduction measures are user-entered records only. Disclaimer required. (Also appears as a checklist category label in template data — unrelated.) |
| KOSHA | Referenced in KO region profile checklist template metadata only. Not embedded in app logic. |
| OSHA / ISO 45001 | May appear in Global region profile template metadata only. Not embedded in app logic. |
| Legal violation determination | **Explicitly prohibited.** The app never asserts a legal violation. |
| Compliance certification | **Out of scope.** The app does not certify compliance. |

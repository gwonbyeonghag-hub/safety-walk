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
| Not Started | 미착수 | No corrective action has been taken yet. Default state. |
| In Progress | 진행중 | Corrective action is underway. |
| Completed | 완료 | Corrective action has been finished. |
| Evidence Photo | 증거 사진 | A photo taken to document a hazard or checklist item result. |
| Region Profile | 지역 프로파일 | A configuration set that controls the default checklist template and reference text. Values: Korea, Global. **Selected implicitly by the Language toggle** (한국어 → Korea, English → Global) — it is no longer a separate user-facing control. Korea = KOSHA-oriented template; **Global = U.S. / OSHA-oriented site-inspection template (imperial units)**. |
| Disclaimer | 면책 고지 | Legal notice that the app does not provide compliance determinations. Required on all exports and in Settings. |

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
```

---

## Status Enums

```swift
enum ChecklistItemResult { case pass, fail, notApplicable, unchecked }
enum RiskLevel           { case low, medium, high }
enum CorrectiveActionStatus { case notStarted, inProgress, completed }
enum InspectionStatus    { case inProgress, completed }
enum RegionProfile       { case korea, global }
enum HazardType          { case fallRisk, electrical, fire, chemical, general, other }
```

---

## Legal / Regulatory Term Handling

| Term | Handling |
|---|---|
| 위험성 평가 (Risk Assessment) | Used as a checklist category label in KO region profile only. Loaded from template data. |
| KOSHA | Referenced in KO region profile checklist template metadata only. Not embedded in app logic. |
| OSHA / ISO 45001 | May appear in Global region profile template metadata only. Not embedded in app logic. |
| Legal violation determination | **Explicitly prohibited.** The app never asserts a legal violation. |
| Compliance certification | **Out of scope.** The app does not certify compliance. |

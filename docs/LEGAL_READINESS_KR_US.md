# SafetyWalk Korea / U.S. Legal Readiness Review

> Review date: 2026-07-13 (Asia/Seoul)
>
> Scope: shipped iOS/iPadOS/macOS code, Korea and Global checklist data, risk-assessment
> workflows, reports, disclaimers, and App Store metadata.
>
> This is a product and implementation gap review based on primary government sources.
> It is not legal advice or a compliance certification. Final release wording and any
> claim of regulatory suitability should be reviewed by a Korean occupational-safety
> professional and U.S. counsel/EHS professional familiar with the target industry and state.

## 1. Executive verdict

The product has a sound **recording-tool foundation**, but it is not yet safe to present as
a complete or "formal" Korean risk-assessment record system, an OSHA-compliant system, or a
TBM/toolbox-talk product.

Launch can proceed after either:

1. implementing the P0 corrections in this report; or
2. reducing the product claim to a general inspection/JHA recording aid, removing unmatched
   claims such as TBM and "formal risk assessment records," and disabling misleading legal
   reminders until the data model is jurisdiction-aware.

The disclaimer is useful, but a disclaimer does not cure a workflow that silently records an
unassessed hazard as Low or labels a U.S. JHA overdue under a Korean-style annual rule.

## 2. What is already directionally correct

- The app does not issue an OSHA/KOSHA compliance verdict.
- Reports and settings include a human-review disclaimer.
- Korea-oriented methods include 3-level, frequency x severity, and checklist approaches.
- The U.S.-oriented JSA/JHA method preserves ordered job steps.
- Risk-assessment items already contain hazards, current controls, proposed measures,
  responsible person, due date, and action status fields.
- Korea A4 and U.S. Letter report layouts are separated for risk-assessment/JHA reports.
- Checklist templates are data-driven rather than embedded in view logic.
- Existing records remain viewable after Pro entitlement lapses.

These choices should be preserved. The required changes are primarily jurisdiction, explicit
input state, participation, control follow-through, record integrity, and product wording.

## 3. P0 findings before a Korea + U.S. launch

### P0-1. Missing risk inputs silently become Low

Evidence:

- `RiskAssessmentItemEditorView.canSave` requires only a task **or** hazard description.
- `DraftItem.directRiskLevel` defaults to `.low`.
- `resolvedLevel(for:)` returns `.low` when likelihood or severity is missing.

Impact:

An incomplete 3-level, frequency-severity, or JSA entry can be persisted and displayed as a
positive Low determination that the user never made. This reverses the intended safety meaning.

Required correction:

- Draft risk selection must begin as **not assessed**, never Low.
- For 3-level/checklist, require an explicit level or explicit "Not assessed."
- For frequency-severity/JSA, require both inputs before producing a score/band.
- Never derive a colored risk band from missing input.
- Existing ambiguous rows must display Unknown/Not assessed, not Low.
- Add tests covering all missing-input combinations.

### P0-2. The Korean risk-assessment record is incomplete under current rules

From 2026-06-01, the Korean Occupational Safety and Health Act Article 36 and Enforcement
Rule Articles 37 through 37-4 strengthen requirements for worker participation, sharing, and
recording. The record must include the timing/person responsible, participating workers and
worker representative, identified hazards, risk decisions, reduction plans, and implementation
results, and must be retained for three years.

Current gaps:

- one `assessorName` only; no participating workers or worker representative;
- no participation method or worker input record;
- no pre-assessment schedule sharing or post-assessment sharing record;
- no stored acceptability criterion or acceptable/unacceptable decision;
- no practical way to update an item after save;
- action status is captured only at creation time;
- `postRiskLevel` exists in the model but has no editor, detail, or report path;
- implementation evidence/result is not recorded;
- site is optional and the assessment scope is weakly defined;
- no explicit three-year retention guidance/export archive.

Required correction:

- Store jurisdiction and assessment scope.
- Store responsible person, participating workers, and worker-representative participation.
- Store the site's risk criteria and acceptable-risk threshold used for that assessment.
- Record current risk, acceptability, measure, control category, owner, due date,
  implementation result/date, and post-measure risk.
- Make saved actions editable with an audit-friendly `updatedAt`/completion trail.
- Record how/when the schedule and results were shared with affected workers.
- Add a Korea-profile retention warning and export/archive path; do not claim that the app
  itself guarantees statutory retention.

### P0-3. Jurisdiction is incorrectly determined by UI language

Current behavior:

- Korean UI automatically selects the Korea template.
- English UI automatically selects `global`.
- `global` is actually a mixed U.S. federal OSHA-oriented template with feet, GFCI, LOTO,
  permit-required confined space, and U.S. general-industry/construction thresholds.
- Site, Inspection, and RiskAssessment do not preserve jurisdiction or industry scope.

Impact:

- A Korean-speaking worker in the U.S. receives the Korea reference template.
- An English-speaking worker in Korea receives the U.S. reference template.
- A template labeled Global contains U.S.-specific thresholds and terminology.
- A historical record cannot establish which jurisdiction/industry/version governed it.

Required correction:

- Separate **UI language** from **safety reference jurisdiction**.
- Replace the visible Global profile with `United States (Federal baseline)` for this launch.
- Select jurisdiction independently in onboarding/settings, preferably per Site.
- Add U.S. industry scope at minimum: General Industry vs Construction.
- Snapshot jurisdiction, industry, template ID/version, and prompt text on each inspection
  and assessment.
- State clearly that OSHA State Plans and local rules may be different or stricter.

### P0-4. The annual due/overdue calculation is not jurisdiction-safe

Current behavior:

- every `.regular` assessment is assigned a 365-day deadline and a red Overdue status;
- the assessment stores no jurisdiction;
- old regular assessments are not grouped by site/latest assessment, so an old record can
  remain overdue even after a newer assessment exists.

Problems:

- Korea's current rule is framed as initial assessment before work, then at least once per
  year from the following year; a fixed 365-day legal deadline is not an adequate model.
- Federal OSHA has no universal annual JHA/risk-assessment deadline.
- OSHA JHA guidance instead recommends review when work changes, incidents/near misses occur,
  controls prove ineffective, and periodically under the employer's program.

Required correction:

- Remove legal-sounding global Overdue behavior.
- Make this a jurisdiction-aware **Review reminder**, not a compliance verdict.
- For Korea, base the reminder on the current rule and latest applicable assessment per
  site/scope, with user-confirmed applicability.
- For the U.S., use a user-selected review date and change/incident triggers.

### P0-5. Corrective-action follow-through is not functional

`RiskAssessmentDetailView` is read-only. The user cannot update Not Started -> In Progress ->
Completed, record the actual implemented control, or reassess residual risk. The Korean process
requires measures to be implemented and their result recorded; OSHA's recommended practices also
call for verifying that controls are effective.

Required correction:

- Add an explicit action-update flow.
- Preserve the original assessment values while recording implementation updates.
- Record completion date, implemented measure/evidence, verifier, and post-control risk.
- Keep Mac read-only if that is a product decision, but provide the complete mutation flow on
  iPhone/iPad and show the synchronized result everywhere.

### P0-6. U.S. reference content mixes incompatible scopes

Examples:

- one fall item combines the 6 ft construction threshold with the 4 ft general-industry
  threshold;
- the GFCI item omits construction's alternative assured equipment grounding conductor
  program and its detailed applicability;
- electrical-panel clearance is simplified to 3 ft although the applicable depth varies;
- respiratory-protection prompts do not represent the complete written-program, medical,
  fit-test, training, and selection requirements;
- state-plan requirements are not represented.

Required correction:

- Split U.S. Federal General Industry and U.S. Federal Construction templates.
- Make conditional prompts say "when applicable" and identify their scope.
- Add template source metadata, reviewed date, and version.
- Treat bundled lists as starting prompts, never an exhaustive legal checklist.
- Have a U.S. EHS professional review every prompt before using OSHA-oriented marketing copy.

## 4. TBM / toolbox-talk assessment

### Korea

Current law calls for affected workers to be informed of risk-assessment matters and says the
employer should make ongoing efforts to communicate hazards capable of leading to serious
accidents through pre-work safety meetings. Under the continuous-assessment approach described
in the Ministry guideline, daily pre-work sharing/TBM is part of that operating method.

SafetyWalk currently has **no TBM data model, screen, attendance record, acknowledgment, or
report**. TBM appears only in Korean and English App Store keywords.

Therefore, choose one before release:

- remove TBM from metadata and do not claim the feature; or
- implement a linked Safety Briefing module.

A bounded Korea TBM record should include:

- site/team, date/time, leader;
- work/task and linked risk-assessment items;
- today's priority hazards, controls, PPE, and emergency action;
- participants/worker representative and communication language;
- questions, suggestions, newly found hazards, and follow-up actions;
- acknowledgment that content was communicated (not a waiver of rights);
- attachment/report and immutable revision history.

Do not store diagnoses, medication, or detailed health data merely because a guide suggests a
health-condition check. A simple fit-for-work escalation flag is safer unless a separate privacy
and occupational-health design is approved.

### United States

There is no single federal rule requiring every employer to conduct a generic weekly toolbox
talk. Requirements are standard- and jurisdiction-specific. For example:

- federal construction electric-power work has a pre-job briefing requirement under
  29 CFR 1926.952;
- California construction requires toolbox/tailgate meetings at least every 10 working days
  under 8 CCR 1509(e).

Accordingly, a U.S. feature should be named **Safety Briefing / Toolbox Talk / Pre-Task Plan**,
store its governing jurisdiction/scope, and avoid promising that one cadence satisfies every
state or operation.

## 5. U.S. JHA/JSA assessment

The existing ordered `job step -> hazard -> controls -> risk` design is directionally consistent
with OSHA's JHA guidance. Improvements needed for a professional worksheet:

- require job/site/location and analysis team;
- involve and record affected workers;
- separate existing controls from recommended controls instead of combining them in one PDF cell;
- record consequences/exposure and control hierarchy where useful;
- record owner, due date, implementation, and effectiveness review;
- permit risk scoring as an employer method, but do not present the 1-3 matrix as an OSHA formula;
- add review triggers for process/equipment changes, incidents, injuries, and near misses;
- keep the statement that the worksheet does not determine OSHA compliance.

For specific legal uses, create separate, explicitly scoped records. Example: a PPE workplace
hazard-assessment certification under 29 CFR 1910.132(d)(2) must identify the workplace evaluated,
certifying person, date(s), and identify the document as the certification. A generic JHA should
not silently claim to be that certification.

## 6. Record integrity and adjacent data issues

### Historical checklist text is mutable

Inspection rows store localization keys and resolve them through the **current** language bundle
at display/export time. If language or a localized prompt changes, an old inspection can display
different wording from what the inspector saw.

For audit-quality records, preserve:

- template ID and semantic version;
- jurisdiction/industry;
- original prompt/category text and locale at creation;
- optional translated display text kept separate from the record snapshot.

### Reset does not explicitly delete RiskAssessment

`SettingsView.performReset()` deletes inspections, hazards, and sites but does not fetch/delete
RiskAssessment rows. Verify this against the active schema and CloudKit behavior. A command called
"Reset local data" must either delete all user records, including assessments, or state exactly
what remains. When Korean statutory retention may apply, warn the user to archive required records
before destructive deletion; the employer remains responsible for retention.

### Reports are not complete legal records yet

The Korea report omits participant/representative, acceptability, actual implementation result,
and post-measure risk. The JHA report combines current and recommended controls and omits action
follow-through. Keep the reports labeled as app-generated records until those gaps are resolved.

## 7. P1 wording and metadata corrections

- Replace `Formal risk assessment records` / `정식 위험성평가 기록` with
  `Risk assessment records` / `위험성평가 기록 지원`.
- Remove `TBM` from App Store keywords until a real TBM flow exists.
- Replace visible `Global` with `United States (Federal baseline)` for the present KR/U.S. launch.
- Expand the disclaimer to mention inspections **and risk assessments**.
- Add: templates are non-exhaustive reference prompts; applicable law depends on work,
  industry, location, and state; competent-person/EHS review is required.
- Do not use `OSHA compliant`, `KOSHA compliant`, `certified`, `official form`, or equivalent.
- Avoid red `Overdue` wording unless a verified jurisdiction-specific deadline is actually known.

## 8. Recommended bounded work orders

### LEGAL-0 — Safety semantics (must go first)

- explicit Not Assessed state;
- no silent Low fallback;
- required method-specific inputs;
- action update + residual risk path;
- unit/UI tests for incomplete and completed states.

### LEGAL-1 — Jurisdiction and record snapshot

- decouple language and jurisdiction;
- Korea / U.S. Federal selection, preferably per Site;
- U.S. General Industry / Construction scope;
- persist jurisdiction, industry, template version, prompt snapshot, and original locale;
- migration and CloudKit tests.

### LEGAL-2 — Korea risk-assessment completeness

- participant/worker-representative records;
- criteria and acceptability decision;
- participation/sharing records;
- implementation result and post-control reassessment;
- current-rule reminder and three-year retention guidance;
- complete Korea PDF.

### LEGAL-3 — U.S. JHA and checklist scope

- professional JHA fields and separate controls;
- U.S. template split and prompt-by-prompt official-source review;
- state-plan disclaimer;
- optional, separately labeled PPE certification workflow only if intentionally implemented.

### LEGAL-4 — TBM product decision

- fast path: remove TBM keyword/claims; or
- full path: jurisdiction-aware Safety Briefing module linked to risk items, participants,
  questions/new hazards, actions, and report.

### LEGAL-5 — Legal copy and external review

- align in-app copy, reports, privacy/support pages, review notes, and App Store metadata;
- Korean safety-professional review;
- U.S. EHS/legal review for federal templates and target launch states;
- freeze reviewed template versions before screenshots/submission.

## 9. Acceptance gate before submission

- No incomplete risk input can render or persist as Low.
- Every saved risk level can be traced to explicit user input and the criteria used.
- Korea record captures current Enforcement Rule 37-4 fields and action follow-through.
- Language changes do not change a historical record's original jurisdiction or prompt text.
- U.S. records identify federal industry scope and display a state-plan caveat.
- No federal annual-JHA compliance deadline is shown.
- TBM is either implemented and tested or absent from all product claims/keywords.
- Korea and U.S. reports contain their required/claimed fields and retain the disclaimer.
- Reset/delete behavior is complete, accurately described, and tested with CloudKit enabled.
- All legal-reference templates carry version, review date, scope, and primary-source links.
- External domain review is documented; no screen or metadata claims legal certification.

## 10. Primary sources

### Korea

- Occupational Safety and Health Act, Article 36, effective 2026-06-01 amendments:
  https://www.law.go.kr/LSW/lsInfoP.do?efYd=20260601&lsiSeq=283449
- Enforcement Rule, Articles 37 through 37-4, Ministry of Employment and Labor Ordinance
  No. 470 (2026-05-29):
  https://www.law.go.kr/LSW/lsRvsDocListP.do?lsId=007364&lsRvsGubun=all
- Ministry guideline, Workplace Risk Assessment Guideline, MOEL Notice 2024-76:
  https://www.law.go.kr/LSW/admRulInfoP.do?admRulSeq=2100000251014
- Ministry of Employment and Labor, 2023 New Risk Assessment Guide:
  https://www.moel.go.kr/policy/policydata/view.do?bbs_seq=20230501085
- KOSHA risk-assessment method guidance:
  https://www.kosha.or.kr/safety1team/tr/reference02.do?articleNo=449159&attachNo=254139&mode=download

### United States

- OSHA Job Hazard Analysis, Publication 3071:
  https://www.osha.gov/Publications/osha3071.html
- OSHA Identifying Hazard Control Options: Job Hazard Analysis:
  https://www.osha.gov/sites/default/files/Job_Hazard_Analysis_Worksheet.pdf
- OSHA Hazard Identification and Assessment recommended practices:
  https://www.osha.gov/safety-management/hazard-identification
- OSHA Worker Participation recommended practices:
  https://www.osha.gov/safety-management/worker-participation
- 29 CFR 1910.132, PPE hazard assessment and written certification:
  https://www.osha.gov/laws-regs/regulations/standardnumber/1910/1910.132
- 29 CFR 1926.20, construction inspections by competent persons:
  https://www.osha.gov/laws-regs/regulations/standardnumber/1926/1926.20
- 29 CFR 1926.21, construction safety training:
  https://www.osha.gov/laws-regs/regulations/standardnumber/1926/1926.21
- 29 CFR 1926.952, electric-power job briefing:
  https://www.osha.gov/laws-regs/regulations/standardnumber/1926/1926.952
- OSHA State Plan overview and caveat:
  https://www.osha.gov/stateplans/faqs
- California 8 CCR 1509(e), construction toolbox/tailgate meetings:
  https://www.dir.ca.gov/title8/1509.html
- Federal fall thresholds, construction and general industry:
  https://www.osha.gov/laws-regs/regulations/standardnumber/1926/1926.501
  https://www.osha.gov/laws-regs/regulations/standardnumber/1910/1910.28
- Construction GFCI/assured grounding alternatives, 29 CFR 1926.404:
  https://www.osha.gov/laws-regs/regulations/standardnumber/1926/1926.404


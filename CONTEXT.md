# CONTEXT.md — SafetyWalk / 현장안전 지킴이

## Project Summary

SafetyWalk is an iPhone-first industrial safety inspection app targeting field safety managers and supervisors.
It replaces paper checklists and post-walkthrough Excel entry with direct on-site recording of inspections, hazards, evidence photos, and corrective action status.

Korean name: **현장안전 지킴이**
Working English name: **SafetyWalk**

---

## Problem

Construction sites and industrial facilities currently rely on:
- Paper checklists filled during walkthroughs
- Post-inspection Excel/spreadsheet data entry (delayed, error-prone)
- Informal verbal notes or phone photos with no structured record

This creates gaps in evidence quality, corrective action tracking, and inspection accountability.

---

## Target Users

| Role | Context | Priority |
|---|---|---|
| Safety Manager | Plans inspections, reviews results, tracks corrective actions | Primary |
| Field Supervisor | Walks the site, records items, takes photos one-handed | Primary |
| (Future) Field Worker | Reports hazards only — no inspection authority | Out of MVP scope |

Both primary roles must be equally well-served. The UX must accommodate varying tech comfort levels.

---

## Core Jobs To Be Done

1. **Record** an inspection against a checklist without paper.
2. **Capture** hazard evidence instantly with the iPhone camera.
3. **Track** corrective action status per hazard.
4. **Review** past inspections on-device.
5. **Share** a simple inspection summary via KakaoTalk, email, or messaging.

---

## Market Context

- Primary market: Korea (construction, manufacturing, facilities management)
- Secondary market: United States (English) — the Global profile uses a U.S./OSHA-oriented checklist template with imperial units
- Legal context: The app does **not** determine legal violations. It supports field recording only.
- Regulatory references (Korea: KOSHA themes, Global: U.S. OSHA themes) are treated as "review required," not binding judgments. No regulation numbers or compliance verdicts appear in app content.

---

## Connectivity Model

**Offline-first.** Local storage is the source of truth for MVP.
Users must be able to complete a full inspection workflow with zero connectivity.
Cloud sync is out of scope for MVP but the data model must not block it later.

---

## MVP Constraints

- iPhone only (SwiftUI, iOS 17+)
- No iPad dashboard layout
- One-handed use, large tap targets, vertical flow
- Local persistence (SwiftData)
- Camera-first hazard recording
- Localization: Korean + English from day one
- Region profiles: Korea / Global (checklist templates are data, not code)
- No automatic legal compliance determination
- No enterprise admin panel
- No cloud sync in MVP

---

## Out of Scope for MVP

- Automatic legal violation judgment
- Final legal compliance determination
- Enterprise admin panel
- Complex statistics dashboard
- Multi-company permissions
- ERP/groupware integration
- Real-time cloud collaboration
- Country-specific compliance certification
- Full PDF automation
- iPad dashboard

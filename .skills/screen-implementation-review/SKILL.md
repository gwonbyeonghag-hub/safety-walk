# Skill: Screen Implementation Review

Run this skill before marking any Phase 2, 3, or 4 screen task as done in TASKS.md.
Also run `/swiftui-build-qa` — it covers type inference errors that this skill does not duplicate.

---

## When to Run

- Before marking a View implementation task `[x]` in TASKS.md
- After fixing a screen-level bug
- After adding a new sheet or navigation destination
- **Required follow-up**: also run `/navigation-qa` after any change that
  touches `NavigationStack`, `NavigationLink`, `.navigationDestination(...)`,
  SwiftData `@Query`, or `@Query` predicate filters — even when the change
  looks innocuous. The ChecklistView depth-2 freeze (3-M7) and back-stack
  misroute (3-M8) were both triggered by changes that looked local but
  failed only when the screen was pushed at depth 2+

---

## Localization Checklist

- [ ] Every user-facing string uses `LocalizationKey.<case>.localized` — no raw string literals in Views
- [ ] Every new string key exists in both `en.lproj/Localizable.strings` and `ko.lproj/Localizable.strings`
- [ ] New keys are added to `LocalizationKey.swift` as a typed case
- [ ] `.strings` files pass `plutil -lint` with no errors
- [ ] Section headers from checklist templates use `NSLocalizedString(group.category, comment: "")` — not hardcoded

---

## UX / Accessibility Checklist

- [ ] All interactive controls have a minimum 44×44pt tap target
- [ ] No horizontal scroll layout on the main inspection flow
- [ ] Risk level indicators (Low/Med/High) are color-coded (green / orange / red) and large
- [ ] List rows with multi-line text use `.fixedSize(horizontal: false, vertical: true)` or equivalent
- [ ] Empty states are shown when lists have no data

---

## Architecture Checklist

- [ ] View does not call a Service directly — service access goes through a ViewModel or is injected
- [ ] No business logic inside `@Model` classes
- [ ] `@Bindable` is used for in-place SwiftData object mutation
- [ ] `@Query` with `#Predicate` is used for reactive filtered fetches (not manual filter on `.items`) — **but not inside a `NavigationLink` destination created in a `ForEach`**, and **not inside a destination pushed at depth-2+** (see SwiftData Safety below)
- [ ] For child data of a parent already passed into the view, prefer `parent.relationship.sorted { ... }` over a new `@Query(filter:)` — relationship-backed reads are safe at any depth, while `@Query` is fragile at depth-2+
- [ ] Photos are saved via `PhotoStorageService` only on user-confirmed save, not on picker selection

---

## Navigation Checklist

Run the full `/navigation-qa` skill for any screen that introduces navigation.
Quick check for screens that are just content views:

- [ ] `.navigationTitle` and `.navigationBarTitleDisplayMode` are set
- [ ] Toolbar buttons use correct `ToolbarItem(placement:)` (`.cancellationAction`, `.confirmationAction`, `.primaryAction`)
- [ ] No `.navigationDestination(isPresented:)` used on a view that is itself a pushed destination

---

## SwiftData Safety

- [ ] No new `@Model` fields added without explicit approval
- [ ] No model fields renamed or removed
- [ ] `modelContext.save()` is called after mutations that must survive a relaunch
- [ ] Relationship arrays (`inspection.hazards`, `inspection.items`) are mutated by appending to the array, not by re-assigning
- [ ] A view that appears as a `NavigationLink` destination inside a `ForEach` does **not** own a `@Query` — if it needs filtered data, receive a pre-filtered `let` array from the parent instead (see `/navigation-qa` for the full rule and code example)
- [ ] A view pushed at depth-2+ (e.g. via `.navigationDestination(isPresented:)` from an already-pushed view) does **not** own `@Query(filter: #Predicate)` — read from the parent model's `@Relationship` instead (see `/navigation-qa` Rule A)
- [ ] A pushed view does not stack both `.navigationDestination(for:)` and `.navigationDestination(isPresented:)` on the same scope (see `/navigation-qa` Rule C)

---

## TASKS.md

- [ ] Task row updated to `[x]` after all acceptance criteria are met
- [ ] Notes column updated if implementation deviated from original spec

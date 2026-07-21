---
name: design-visual-qa
description: Use to verify the visual design quality of a SafetyWalk screen by rendering it, capturing a screenshot, and critiquing the result — not by reading code. Run on UI work needing a visual pass.
---

# Skill: Design Visual QA (render → screenshot → critique → iterate)

Run this skill to verify the **visual design quality** of a screen by actually
rendering it, capturing a screenshot, and critiquing what you see — not by
reading the code and assuming it looks right.

This is the visual counterpart to runtime verification: a screen only passes
when *you have looked at a real screenshot of it* and scored it against the
rubric below.

---

## Relationship to other skills (do not duplicate)

Run those first; this skill assumes they passed:

- `/swiftui-build-qa` — it compiles (type inference, `.tint`, ternaries).
- `/screen-implementation-review` — it works and is accessible (localization,
  44×44pt targets, no horizontal scroll, risk color-coding, empty states,
  MVVM/SwiftData rules).
- `/navigation-qa` — navigation does not freeze.

**This skill does NOT recheck those.** It answers a different question:
*does the screen look like a polished, fast field tool — or like an unstyled
default?* Functional-correct and visually-good are separate axes.

---

## When to Run

- Before marking a Phase 2/3/4 screen task `[x]` in TASKS.md, after the
  functional skills above pass.
- After any change to layout, spacing, typography, color, or component styling.
- When a screen "compiles and works" but feels rough and you cannot say why.

---

## The Loop

Never report visual QA from code alone. Run this loop:

```text
1. Build & launch in the iOS Simulator (use the build steps from /swiftui-build-qa).
2. Navigate to the target screen (and its key states: empty, populated, long text,
   High-risk row, error/loading if any).
3. Capture a screenshot of each state:
     xcrun simctl io booted screenshot /tmp/safetywalk-<screen>-<state>.png
4. READ the screenshot image. Actually look at it. Score it against the Rubric.
5. Fix the highest-severity issues only (do not micro-tweak everything at once).
6. Re-build, re-screenshot the same states, re-score.
7. Repeat until the Pass Bar is met or you hit 3 iterations.
8. If still failing after 3 iterations, stop and report to the human with the
   screenshot and the blocking rubric items — do not loop forever.
```

Capture the **same viewport for before/after** so the diff is honest. Always
check at least the empty state and the most-populated state — most visual
breakage hides in one extreme.

---

## Rubric (score each group: PASS / NEEDS-WORK, with screenshot evidence)

### 1. Hierarchy
- [ ] One clear focal point per screen; the primary action is the most prominent thing.
- [ ] Reading order matches task order (what the inspector does first is on top / largest).
- [ ] Secondary/tertiary elements are visibly de-emphasized, not competing.

### 2. Spacing rhythm
- [ ] Spacing follows a consistent scale (e.g. 4 / 8 / 16 / 24), not arbitrary paddings.
- [ ] Related items are grouped by proximity; unrelated groups have clear separation.
- [ ] No cramped edges and no accidental large gaps that look like a layout bug.

### 3. Typography
- [ ] At most ~2–3 text roles per screen (e.g. title / body / caption); not five sizes.
- [ ] Clear size/weight jump between title and body — hierarchy is felt, not measured.
- [ ] Line spacing and multi-line wrapping are comfortable; nothing truncated mid-word.

### 4. Color & contrast
- [ ] Restrained palette; color carries **meaning** (risk Low=green / Med=orange /
      High=red), not decoration.
- [ ] Text/background contrast is strong enough to read **outdoors in bright light**
      (this is a field tool — assume sunlight, gloves, a cracked screen).
- [ ] No two interactive colors that could be confused for each other.

### 5. Alignment & polish tells
- [ ] Elements share alignment edges (left edges line up; icons baseline with text).
- [ ] Consistent corner radius and component styling across the screen.
- [ ] Lists/rows that carry rich content read as intentional rows/cards, not a raw
      default `List` dump.
- [ ] Empty state is designed (icon + one line + clear next action), not blank.

### 6. Motion (only if the screen animates)
- [ ] Animation is purposeful and fast; it never blocks reading or tapping.
- [ ] Content is fully settled before interaction is expected.

### 7. SafetyWalk design intent (project-specific)
- [ ] Reads as a **fast, glanceable field tool**, not a dashboard (CLAUDE.md: "No
      dashboard-style screen").
- [ ] Primary risk/record actions are reachable with one thumb (bottom-ish, large).
- [ ] Risk level is large and unmistakable at arm's length.
- [ ] Nothing on screen implies a legal/violation judgment (CLAUDE.md rule).

---

## Pass Bar

A screen passes visual QA when, **with a screenshot as evidence**:

- Groups 1 (Hierarchy), 2 (Spacing), 4 (Contrast), and 7 (Intent) are all PASS.
- At most one NEEDS-WORK remains among groups 3, 5, 6 — and it is logged as a
  minor follow-up, not silently dropped.

If a core group (1/2/4/7) is NEEDS-WORK, the screen does **not** pass — fix and
re-screenshot.

---

## Variation mode (optional — when direction is unclear)

When the right layout is genuinely uncertain, don't guess once:

1. Generate 2–3 distinct layout variants of the screen (not minor tweaks — real
   alternatives: list vs card, top-action vs bottom-action, dense vs spacious).
2. Screenshot each in the same states.
3. Compare **pairwise** against the rubric (pairwise is more reliable than scoring
   each in isolation), pick the strongest.
4. Present the winner + one runner-up screenshot to the human for the final call.

---

## Human checkpoint (taste is not fully automatable)

This skill automates the **mechanical, checkable** parts of visual quality
(hierarchy, rhythm, contrast, consistency) and the act of *looking*. It does
**not** decide brand/taste direction on its own. After the loop converges:

- Post the final screenshot(s) and the per-group verdict.
- State which variant was chosen and why.
- Ask the human to confirm the **direction** (does it feel right for the app),
  not the pixels.

Direction stays a human decision; everything up to it is automated.

---

## Output format

Report, not prose:

```text
Screen: <name>   States checked: empty / populated / long-text / high-risk
Screenshots: <paths>

Hierarchy:   PASS
Spacing:     PASS
Typography:  NEEDS-WORK → title/body size jump too small (logged as follow-up)
Color/contrast: PASS
Alignment/polish: PASS
Motion:      n/a
SafetyWalk intent: PASS

Changes made this loop: <1–3 highest-severity fixes>
Iterations: 2/3
Verdict: PASS (1 minor follow-up logged)
Needs human eyes: confirm bottom-action layout matches the field-tool intent.
```

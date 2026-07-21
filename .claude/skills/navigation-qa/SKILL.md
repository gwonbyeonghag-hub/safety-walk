---
name: navigation-qa
description: Use after any SafetyWalk navigation or screen-transition change to verify the actual push/pop/sheet/split flow behaves correctly.
---

# Skill: Navigation QA

Run this skill after any navigation or screen transition change.

---

## When to Run

- After adding or modifying a `NavigationLink`, `.sheet`, or `.navigationDestination`
- After fixing a button that is supposed to push or present a screen
- After any change to `NavigationStack(path:)` or `FlowStep` enum
- Before marking any Phase 2 screen task done

---

## Rules

### Do not wrap `.sheet` destinations in a `NavigationStack` when also using `.navigationDestination`
Using `.sheet(isPresented: $bool) { NavigationStack { View } }` on a pushed view
inside `NavigationStack → TabView` creates a `UISheetPresentationController` host
that intercepts ALL touch delivery — including the UIKit back button — even when
`$bool` is `false`. The freeze persists until the `.sheet` modifier is removed.

**Rule**: never attach `.sheet` to a pushed navigation destination. Use
`.navigationDestination(isPresented: $bool) { View }` instead (no `NavigationStack`
wrapper; the destination is pushed onto the existing stack, so toolbars/titles work).

**Exception**: if the destination view contains its own `NavigationStack`, keep it
in a `.sheet` but host the `.sheet` on a non-pushed root view (e.g., the `TabView`
root, not a depth-2 pushed view).

### Sheet presentations require a NavigationStack wrapper only when hosted at root level
If a view shown via `.sheet` uses `.navigationTitle`, `.toolbar`, or
`.navigationBarBackButtonHidden`, wrap it: `.sheet { NavigationStack { MyView() } }`.
This applies only when the `.sheet` is on a non-pushed root view.
When pushing onto an existing stack via `.navigationDestination(isPresented:)`,
no wrapper is needed — the view inherits the existing `NavigationStack`.

### Cascade dismiss pattern
When a pushed view needs to dismiss itself after a child presentation closes,
use `.onChange(of: showChild) { _, isShowing in if !isShowing && condition { dismiss() } }`.
Do not chain `dismiss()` calls across boundaries — let state drive the chain.

### `NavigationStack(path:)` with typed enum
Use a `FlowStep: Hashable` enum for multi-step flows. Register all destinations
on the root view via `.navigationDestination(for: FlowStep.self)`. Never split
destination registrations across pushed views.

### `isDone` pattern for sheet flows
When a sheet flow (e.g., StartInspectionFlow) needs to close from a deep step,
pass a `@Binding var isDone: Bool` through the chain. The sheet root observes
`.onChange(of: isDone)` and calls `dismiss()`. Do not call `dismiss()` from
deep steps directly — it only pops one level.

### Do not put `@Query` inside a `NavigationLink` destination created in a `ForEach`
SwiftUI may eagerly evaluate **all** destination closures in a `ForEach` during
the layout pass, even before the user taps anything. When each destination
runs a `@Query(filter:)` in its `init`, SwiftData registers N simultaneous
fetch descriptors on the main thread. This stalls layout and freezes the entire
navigation stack: scroll stops, row taps stop, and the UIKit back button stops
responding. The freeze is silent — no crash, no error, just a dead screen.

**Root cause observed**: `ChecklistView` had 14 `NavigationLink` destinations
each constructing `ChecklistCategoryDetailView(categoryKey:)`, which owned a
compound-predicate `@Query`. All 14 were eagerly initialized during layout.

**Rule**: detail views that appear as `NavigationLink` destinations inside a
`ForEach` must not own a `@Query`. Keep one `@Query` in the parent view, group
or filter the results there, and pass the pre-filtered array as a `let`
parameter to the destination.

**Exception**: a destination view may own `@Query` if it is navigated to as a
standalone root screen (not inside a `ForEach`) and the query is proven safe
(e.g., single destination, no repeated init).

```swift
// BAD — 14 @Query instances created eagerly during layout
ForEach(categories) { category in
    NavigationLink {
        ChecklistCategoryDetailView(categoryKey: category.key)
        // ↑ init runs @Query(filter: #Predicate { item.category == key })
    } label: {
        CategoryRow(category: category)
    }
}

// GOOD — one @Query in the parent; destination receives a plain array
@Query private var allItems: [ChecklistItem]

private var groupedItems: [(category: String, items: [ChecklistItem])] { ... }

ForEach(groupedItems, id: \.category) { group in
    NavigationLink {
        ChecklistCategoryDetailView(
            inspection: inspection,
            categoryKey: group.category,
            items: group.items          // ← pre-filtered [ChecklistItem]
        )
    } label: {
        CategoryRow(group: group)
    }
}

// Detail view — no @Query, no SwiftData import needed
struct ChecklistCategoryDetailView: View {
    let inspection: Inspection
    let categoryKey: String
    let items: [ChecklistItem]          // ← plain let, not @Query
    // @Bindable in ChecklistItemRow still works; @Model is @Observable
}
```

**Note on `@Bindable` in child rows**: even though the detail view receives
a `let items: [ChecklistItem]` array, `ChecklistItemRow` can still use
`@Bindable var item: ChecklistItem` for in-place mutations. SwiftData `@Model`
classes are `@Observable`; the binding works without a `@Query` on the parent.

### Do not put `@Query` with `#Predicate` inside a depth-2+ pushed destination
A destination view reached via `.navigationDestination(isPresented:)` (or
`.navigationDestination(for:)`) **from another already-pushed view** (depth-2
or deeper in the navigation stack) must not own a `@Query(filter: #Predicate)`.
On iOS 17/18, evaluating `#Predicate` during the push at this depth froze the
entire app silently — no crash, no console output, just an unresponsive UI.

The same `@Query` was confirmed safe at depth 0 (tab root) and depth 1 (single
push from root). The failure is specific to depth-2+ destinations.

**Diagnostic that confirmed this**: a destination receiving `let inspection: Inspection`
with no `@Query` worked. Adding `@Query private var items` with the same
`#Predicate<ChecklistItem> { $0.inspectionId == id }` inside the **same** depth-2
destination froze the app immediately after the navigation push, with the
button-tap print firing but the destination's `.onAppear` never running.

**Rule**: in a destination that is itself pushed from a pushed view, read related
records via the parent model's `@Relationship` instead of issuing a new `@Query`.

```swift
// BAD — @Query inside a destination that is itself a pushed view
struct ChecklistView: View {
    @Bindable var inspection: Inspection
    @Query private var items: [ChecklistItem]
    init(inspection: Inspection) {
        self.inspection = inspection
        let id = inspection.id
        _items = Query(
            filter: #Predicate<ChecklistItem> { $0.inspectionId == id },
            sort: [SortDescriptor(\ChecklistItem.sortOrder)]
        )
    }
    // pushed via .navigationDestination(isPresented:) from InspectionDetailView
    // → freezes the entire app at push time
}

// GOOD — read items via the @Relationship on Inspection
struct ChecklistView: View {
    @Bindable var inspection: Inspection
    private var items: [ChecklistItem] {
        inspection.items.sorted { $0.sortOrder < $1.sortOrder }
    }
}
```

**Why the relationship is safe**: `Inspection.@Relationship var items: [ChecklistItem]`
faults in on access, but SwiftData resolves the relationship lazily without
registering a separate fetch descriptor during view init. There is no parallel
fault storm at push time.

**Apply this rule to**: `ChecklistView`, `InspectionSummaryView`, any future
view that is reached via a depth-2+ push and needs items for the current
`Inspection`. The same applies to other parent→children relationships.

### Do not co-locate `.navigationDestination(for:)` and `.navigationDestination(isPresented:)` on the same pushed view
At depth-2 on iOS 17/18, attaching BOTH a type-based destination and an
`isPresented`-based destination to the same pushed view causes the system's
back-button pop to land on the **wrong screen**. The view renders correctly
on push, but back navigation returns to one of the registered destinations
instead of the parent.

**Observed**: `ChecklistView` (depth-2) had both
`.navigationDestination(for: CategoryRoute.self)` (category rows) and
`.navigationDestination(isPresented: $showSummary)` (summary). Tapping Back
from `ChecklistCategoryDetailView` returned to "an unexpected checklist /
intermediate state" instead of the category overview.

**Rule**: on a pushed view that needs to push children, use exactly one
navigation mechanism. If only one child screen is "deep" (lazy/programmatic),
keep `.navigationDestination(isPresented:)` and use **closure-based**
`NavigationLink { Destination(...) } label: { ... }` for the others — provided
the closure destination owns no `@Query` (see depth-2 `@Query` rule above).

```swift
// BAD — two destinations on the same pushed view → back lands wrong
.navigationDestination(for: CategoryRoute.self) { ... }      // categories
.navigationDestination(isPresented: $showSummary) { ... }    // summary

// GOOD — closure-based NavigationLink for the categories; keep one isPresented:
ForEach(groups) { group in
    NavigationLink {
        ChecklistCategoryDetailView(items: group.items, ...)   // no @Query
    } label: { CategoryRow(group: group) }
}
// ...
.navigationDestination(isPresented: $showSummary) {
    InspectionSummaryView(inspection: inspection)
}
```

**Why closure-based is now safe**: the original 2-M6 freeze was specifically
about `@Query` inside the destination struct's `init` running 14× during the
eager destination-instance creation. Once the destination has no `@Query`
(items passed in as `let`), its `init` just stores parameters — `body` is
not evaluated until the user actually taps the link.

### Weigh `NavigationLink` destination cost in a `ForEach` — not just `@Query`
The `@Query`-eager-init bug is the **most common** ForEach freeze cause, but
not the only one. Any destination that does meaningful work in `init` (not
`body`) gets multiplied by the row count and can stall the layout pass.

Destination-construction red flags inside a `ForEach`:

- `@Query(filter: #Predicate)` (registers a SwiftData fetch descriptor at `init`)
- Manual `Query(...)` assignment in a custom `init`
- `PhotosPicker` and `.photosPicker(...)` modifiers wired up in `init`
- Many `@State` declarations on per-row child views inside the destination
- `.onAppear` blocks that do **synchronous disk / image / data loading**
- Nested `List` / `ScrollView` that the destination eagerly constructs
- Heavy computed properties referenced during `init` (e.g. building a large
  grouped array eagerly)

**Decision rule for `ForEach` NavigationLinks**:

| Destination shape | Mechanism to use |
|---|---|
| Owns `@Query` / heavy `init` work | `NavigationLink(value:)` + one `.navigationDestination(for:)` — lets you skip the eager closure call entirely |
| Lightweight: `let` parameters only, no `@Query`, no eager work | Closure-based `NavigationLink { Destination(...) } label: { ... }` is acceptable; SwiftUI only evaluates the destination's `body` on tap |

**Lightweight does not mean "small `body`"** — it means cheap `init`. A
destination whose `body` later renders a 1,000-row `List` is still fine if
the construction itself stores three `let` properties and nothing else.

---

## Diagnostic Procedure: entire screen frozen (scroll + tap + back button)

When a pushed screen renders visually but scroll, row taps, and the back
button are non-responsive — or a button tap fires (its print appears) but
the next screen never reaches `.onAppear` — **do not apply speculative fixes**.
Isolate via staged rebuild, in this order:

### Step 1 — Replace `body` with a minimal debug body

```swift
var body: some View {
    ScrollView {
        VStack { ForEach(0..<5, id: \.self) { Text("Row \($0)").padding() } }
    }
    Button("Tap") { print("tap") }.buttonStyle(.borderedProminent).padding()
}
```

If the minimal body still freezes, the cause is **upstream**: the parent
push, the navigation registration, or the route value type — not this view.

### Step 2 — Stage components back in, one at a time

For a destination view, the recommended stage order is:

1. **Model parameter only** (`let inspection: Inspection`, plain `Text`/`Button`)
2. **Relationship-backed data** (`inspection.items.sorted { ... }`, render count)
3. **`@Query` with `#Predicate`** (only if the relationship path isn't applicable)
4. **Grouping / derived arrays** (`groupedItems`, plain `Text` rows)
5. **`NavigationLink` to a `Text` destination** (proves push mechanism)
6. **Real row view** (e.g. `ChecklistItemRow`) — first without `.onAppear`,
   then with
7. **Image / photo loading**, sheets, PhotosPicker
8. **Summary / completion navigation** last

Stop at the **first** failing stage. That is the cause.

### Step 3 — Confirm tap delivery before blaming the destination

When the user reports a freeze after a button tap, place two `print`
statements before and after the state mutation:

```swift
Button {
    print("[FREEZE-DIAG] tap fired")
    showChild = true
    print("[FREEZE-DIAG] state set to true")
} label: { Text("Continue") }
```

Then add a `.onAppear { print("[FREEZE-DIAG] destination appeared") }` on the
destination. The console pattern tells you which side froze:

| Console pattern | What's frozen |
|---|---|
| All three prints, then UI hangs | Inside the destination's `body` |
| First two prints, no `.onAppear` | Push transition / destination `init` / SwiftData fault storm |
| Only the tap-fired print | Synchronous work inside the button action |
| No prints | Tap isn't reaching the button (parent intercepting touches) |

### Step 4 — Common suspects (in priority order)

1. `@Query(filter: #Predicate)` in a depth-2+ pushed destination
2. `@Query` inside a `NavigationLink` destination created in a `ForEach`
3. Two `.navigationDestination(...)` registrations on the same depth-2 view
4. `.sheet(isPresented:)` attached to a pushed view
5. `.disabled(true)` inside `.safeAreaInset` propagating to parent
6. `GeometryReader` consuming all hit-testing surface
7. Stale build / DerivedData (always clean-build before deep diagnosis)

These are **suspects to disprove with staged isolation**, not "first try this fix" recipes.

### Decisive diagnostic sequence from the SafetyWalk ChecklistView blocker

For future reference, this is the exact sequence that isolated the depth-2
`@Query` freeze. Reproduce the pattern for similar future bugs:

1. `InspectionDetailView` reduced to minimal body — worked
2. Added header card, `@Query`, counts, grouping, `DetailItemRow`, `.onAppear`
   photo load — each stage worked at depth 1
3. Added Continue button → plain `Text` destination — worked
4. Switched destination to real `ChecklistView` — froze
5. Replaced destination with a tiny `ChecklistDiagStage` accepting `let inspection`
   (stage C1) — worked
6. C2: added the same `@Query` with `#Predicate` that `ChecklistView` used — froze
7. C2b: removed `@Query`, switched to `inspection.items.sorted { ... }` — worked
8. Applied the relationship-backed fix to real `ChecklistView` and
   `InspectionSummaryView` — freeze resolved

The fix landed without ever rewriting unrelated screens or applying
speculative patches.

---

## Verification Checklist

Before marking a navigation change done, confirm each manually:

- [ ] Every path that should push a view does so — no silent drops
- [ ] Back navigation does not get stuck on any screen
- [ ] No `.sheet` modifier is attached to a view that is itself a pushed navigation destination
- [ ] Sheets open and dismiss without freezing the navigation stack
- [ ] Cascade dismiss lands the user on the correct screen (not mid-stack)
- [ ] Multi-step flows use `NavigationStack(path:)` with a typed enum
- [ ] `InspectionSummaryView` is pushed via `.navigationDestination(isPresented:)` from ChecklistView (no NavigationStack wrapper)
- [ ] "Continue Inspection" uses `NavigationLink`, not a `@State` flag + `.navigationDestination`
- [ ] No `@Query` runs inside a `NavigationLink` destination that is created in a `ForEach` (see SwiftData rule above)
- [ ] No `@Query(filter: #Predicate)` runs inside a destination reached via `.navigationDestination(isPresented:)` or `.navigationDestination(for:)` from a view that is itself pushed (depth-2+); use the parent model's `@Relationship` instead
- [ ] A single pushed view does not stack both `.navigationDestination(for:)` and `.navigationDestination(isPresented:)`; pick one mechanism (closure-based `NavigationLink` for the other paths)

---

## Known Fragile Patterns in This Codebase

| Pattern | Why It Breaks | Fix |
|---|---|---|
| `.sheet(isPresented: $bool)` on a pushed view | `UISheetPresentationController` host intercepts ALL touches even when `$bool = false`; back button stops working | Use `.navigationDestination(isPresented: $bool)` instead |
| `@Query` inside a `NavigationLink` destination in a `ForEach` | SwiftUI eagerly evaluates all N destination closures during layout; N simultaneous SwiftData fetch descriptors stall the main thread; scroll, tap, and back button all freeze | Keep one `@Query` in the parent; pass pre-filtered `[Model]` array as `let` to the destination (see rule above for full example) |
| `@Query(filter: #Predicate)` inside a destination pushed at depth-2+ via `.navigationDestination(isPresented:)` or `.navigationDestination(for:)` | iOS 17/18 SwiftData: evaluating `#Predicate` during the push at this depth freezes the entire app silently — destination's `.onAppear` never fires; same `@Query` is safe at depth 0/1 | Read related records via the parent's `@Relationship` (e.g. `inspection.items.sorted { $0.sortOrder < $1.sortOrder }`) — no `@Query`, no `init` override |
| `if let` inside `navigationDestination` closure | Returns `_ConditionalContent`, breaks type inference | Use `NavigationStack(path:)` with enum |
| `dismiss()` from deep step in a sheet flow | Only pops current level | Use `@Binding isDone` chain |

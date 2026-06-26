# Skill: SwiftUI Build QA

Run this skill before reporting any SwiftUI screen task as complete.
Apply these rules proactively when writing new View code.

---

## When to Run

- Before marking any Phase 2/3/4 screen task done
- After writing or editing any code that uses `.tint(...)`, color shorthands, or ternary expressions in view modifiers
- After writing `@ViewBuilder` properties or computed View properties with branching return types

## Scope

This skill covers **Swift-level type-inference and compile-time fragility**.
It does **not** cover SwiftData / navigation runtime freezes — those live in
`/navigation-qa`. If the symptom is "compiles fine, app freezes / locks UI",
go to `/navigation-qa` (especially the depth-2+ `@Query` and co-located
`.navigationDestination` rules).

---

## Rules

### `.tint(...)` requires `Color`, not `ShapeStyle`
The `.tint(_ tint: Color?)` modifier on `ButtonStyle` (`.bordered`, `.borderedProminent`) and
`PhotosPicker` expects a `Color` argument. `ShapeStyle` types such as `.secondary` and `.accentColor`
resolve to `TintShapeStyle` or `HierarchicalShapeStyle` when the compiler can't infer `Color`, causing:

> Type 'ShapeStyle' has no member 'accentColor'
> Member 'tint' expects argument of type 'Color'

**Fix**: always use explicit `Color.` prefix in `.tint(...)`:
```swift
// Wrong
.tint(.secondary)
.tint(.accentColor)
.tint(condition ? .secondary : .accentColor)

// Correct
.tint(Color.secondary)
.tint(Color.accentColor)
.tint(condition ? Color.secondary : Color.accentColor)
```

### Ternary expressions must have a uniform concrete type
A ternary `condition ? A : B` infers the type from both branches simultaneously.
If `A` and `B` resolve to different types (`Color` vs `ShapeStyle` vs `TintShapeStyle`),
the compiler errors. Use explicit type annotations on both branches, or extract to a helper:

```swift
// Wrong — mixed ShapeStyle / Color
.foregroundStyle(flag ? .green : .secondary)

// Correct — explicit Color on both sides
.foregroundStyle(flag ? Color.green : Color.secondary)

// Also correct — helper function with explicit return type
private func stateColor(_ flag: Bool) -> Color {
    flag ? .green : Color(.systemGray)
}
```

### `.foregroundStyle(...)` shorthand is safe with identical types
When both branches of a ternary are `Color` (e.g. `Color.green` and `Color.red`),
`.foregroundStyle(...)` works without issues. The problem only arises when mixing hierarchy styles.

### Computed `View` properties with branching return types need `@ViewBuilder`
A `var foo: some View` property that has a `switch` or `if/else` returning structurally
different view types will fail without `@ViewBuilder`:

```swift
// Wrong — different concrete types per branch
private var icon: some View {
    switch state {
    case .a: return Image(systemName: "a")       // Image
    case .b: return Text("b")                    // Text — compiler error
    }
}

// Correct
@ViewBuilder private var icon: some View {
    switch state {
    case .a: Image(systemName: "a")
    case .b: Text("b")
    }
}
```

### Prefer explicit `Color(...)` for system colors in modifiers
`Color(.systemGray)`, `Color(.systemGray3)`, `Color(.systemGray5)` are always `Color` —
safe in any modifier that expects `Color`. Use these instead of their shorthand equivalents
when the context is type-sensitive.

### Smallest fix rule
Do not rewrite a view to fix a type inference error. Locate the exact expression causing
the error and add the explicit type prefix. One-line changes are almost always sufficient.

---

## Quick Checklist

Before committing new SwiftUI view code, scan for:

- [ ] `.tint(...)` — is the argument explicitly `Color`?
- [ ] Ternary in `.tint(...)` — are both branches the same concrete type?
- [ ] Ternary in `.foregroundStyle(...)` — are both branches the same concrete type?
- [ ] Computed `some View` property with `switch` or `if/else` — does it have `@ViewBuilder`?
- [ ] Any `.secondary`, `.primary`, `.accentColor` shorthand in a type-sensitive context — add `Color.` prefix

---

## Related

- `/navigation-qa` — runtime navigation, push-depth, SwiftData `@Query` freezes,
  staged-rebuild diagnostic procedure. Use that skill for any "compiles but the
  UI hangs / back button doesn't work" symptom.
- `/screen-implementation-review` — pre-merge view checklist (localization,
  accessibility, MVVM, SwiftData safety).

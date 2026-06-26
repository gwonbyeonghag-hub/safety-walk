# Skill: Checklist Template Expansion

Run this skill when adding or modifying checklist template items or categories.

---

## When to Run

- Before adding items to `checklist_korea.json` or `checklist_global.json`
- When adding a new template category
- When adding localization keys for new checklist items
- When validating that templates and strings are in sync

---

## JSON Structure

Templates live in `Resources/Templates/`. Each file must match:

```json
{
  "templateId": "region-general-v1",
  "name": "Display Name",
  "regionProfile": "korea" | "global",
  "version": 1,
  "categories": [
    {
      "categoryKey": "checklist.category.fallRisk",
      "items": [
        {
          "titleKey": "checklist.item.korea.fall.001",
          "sortOrder": 1
        }
      ]
    }
  ]
}
```

---

## Key Naming Conventions

### Category keys
Format: `checklist.category.<camelCaseName>`
Examples: `checklist.category.fallRisk`, `checklist.category.electrical`

Category keys are shared between Korea and Global templates.
A category key used in one template must have the same localized value in the other.

### Item title keys
Format: `checklist.item.<region>.<abbreviatedCategory>.<NNN>`
- `<region>`: `korea` or `global`
- `<abbreviatedCategory>`: `fall`, `elec`, `fire`, `chem`, `general`
- `<NNN>`: zero-padded 3-digit counter, restarting per category

Examples: `checklist.item.korea.fall.001`, `checklist.item.global.chem.003`

### sortOrder
Must be sequential integers starting at 1, scoped per category. Do not reuse numbers
within a category. Order across categories is determined by category list order in JSON.

---

## Localization Sync Rules

Every `titleKey` and `categoryKey` in a JSON template must have a matching entry in:
- `en.lproj/Localizable.strings`
- `ko.lproj/Localizable.strings`

Both files must be updated in the same commit. Never add a key to one file without the other.

---

## Validation Steps

1. After editing JSON, open in Xcode and confirm it parses without errors.
2. After editing `.strings`, run: `plutil -lint <path-to-file>` — must return "OK".
3. Cross-check: every `titleKey` in JSON exists in both `.strings` files.
4. Cross-check: every new key in `.strings` is also in `LocalizationKey.swift` if used in Swift source.
5. Build and run: open the template selection step and verify new items appear with correct text.

---

## What Checklist Items Must Not Contain

- No reference to specific regulation numbers (e.g., OSHA 1926.502, KOSHA GUIDE)
- No legal compliance pass/fail judgments — items describe observable conditions only
- No scoring weights — items are Pass/Fail/NA only
- No hard-coded Swift arrays — all items must come from JSON via `ChecklistTemplateLoader`

---

## Current Template Inventory

| File | templateId | Categories | Items |
|---|---|---|---|
| checklist_korea.json | korea-general-v1 | 14 | 42 |
| checklist_global.json | global-general-v1 | 14 | 42 |

Categories (both templates, same order):
commonSafety, housekeeping, ppe, fallRisk, electrical, fire, chemical,
forklift, industrialRobot, pressMachine, conveyorRotating, craneHoist,
confinedSpace, emergencyResponse

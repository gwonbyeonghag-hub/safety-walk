import SwiftUI

extension Color {
    /// DOMAIN_TERMS 낮음(low) risk color = yellow/gold.
    ///
    /// A deeper gold rather than the bright system `.yellow`: it stays legible as
    /// foreground text/number on light backgrounds *and* under white text on a solid
    /// fill (selected risk chips / active filter), in both light and dark mode — the
    /// bright `.yellow` failed those contrast cases. Matches the print-gold used by the
    /// PDF report so 낮음 reads the same across app and export. High = red, Medium =
    /// orange are unchanged; green stays reserved for 완료·안정·적합.
    static let riskLow = Color(red: 0.70, green: 0.52, blue: 0.00)

    /// Non-risk attention / validation color — name-required, nothing-selected, and
    /// failed-item flags. Same hue as system orange, but named so it reads as an
    /// intentional **warning**, distinct from risk-medium (`RiskLevel.uiColor`). Navy
    /// stays the app accent; this is never used as an accent.
    static let warning = Color.orange
}

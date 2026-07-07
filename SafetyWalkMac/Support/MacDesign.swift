import SwiftUI
import AppKit

// WO-8 macOS design tokens — the "refined native" system ported from the owner-approved
// mockup (docs/design/macos-dashboard-mockup.html, CSS `:root`). macOS-target only: none
// of this leaks into the shared SafetyWalkCore or the iOS target. The risk-level color
// language (RiskChip/RiskDot/RiskLevel.uiColor) is the app-wide SIGNATURE and is
// intentionally NOT redefined here — WO-8 keeps it exactly as-is (DESIGN_DIRECTION §1).
//
// Cool-biased neutrals + navy accent; light/dark values are the mockup's two `:root`
// blocks. Colors adapt via an NSColor dynamic provider so they also follow the app's own
// appearance picker (`.preferredColorScheme`), not just the system setting.

// MARK: - Adaptive color helper

private func macDynamic(light: (UInt, Double), dark: (UInt, Double)) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let (hex, alpha) = isDark ? dark : light
        return NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    })
}

private func macDynamic(light: UInt, dark: UInt) -> Color {
    macDynamic(light: (light, 1), dark: (dark, 1))
}

extension Color {
    // Surfaces / structure
    static let macBg          = macDynamic(light: 0xF4F6F9, dark: 0x15181E)
    static let macSurface     = macDynamic(light: 0xFFFFFF, dark: 0x1D2027)
    static let macSurface2    = macDynamic(light: 0xFAFBFD, dark: 0x22262E)
    static let macSidebar     = macDynamic(light: 0xEEF1F6, dark: 0x191C22)
    static let macBorder      = macDynamic(light: 0xE3E7EE, dark: 0x2B303A)
    static let macBorderStrong = macDynamic(light: 0xD6DBE4, dark: 0x363C48)

    // Ink / text
    static let macInk    = macDynamic(light: 0x1A1E26, dark: 0xE9ECF2)
    static let macInk2   = macDynamic(light: 0x3A4150, dark: 0xC2C8D2)
    static let macMuted  = macDynamic(light: 0x727B8C, dark: 0x8B93A2)
    static let macFaint  = macDynamic(light: 0x9AA3B2, dark: 0x666E7D)

    // Accent (cool navy — app chrome / interactive, per DESIGN_DIRECTION; warm ramp = risk)
    static let macAccent     = macDynamic(light: 0x2360C9, dark: 0x5C9BF5)
    static let macAccentInk  = macDynamic(light: 0x1E56B6, dark: 0x7FB0F7)
    static let macAccentSoft = macDynamic(light: (0x2360C9, 0.10), dark: (0x5C9BF5, 0.15))

    // OK / stable green (mockup `--ok`) — reserved for 완료·안정 (DESIGN_DIRECTION), never risk.
    static let macOk = macDynamic(light: 0x2C9A57, dark: 0x40B673)

    // Soft shadow tint (mockup `--shadow`)
    static let macShadow = macDynamic(light: (0x141C2D, 0.10), dark: (0x000000, 0.36))
}

// MARK: - Metrics (8pt grid, mockup radii)

enum MacTheme {
    static let cardRadius: CGFloat = 12
    static let smallRadius: CGFloat = 8

    // 8pt spacing scale
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
}

// MARK: - Card surface + section label

extension View {
    /// The mockup card: token surface + hairline border + soft shadow, at a given radius.
    func macCardSurface(radius: CGFloat = MacTheme.cardRadius) -> some View {
        self
            .background(Color.macSurface, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Color.macBorder, lineWidth: 1)
            )
            .shadow(color: Color.macShadow, radius: 5, x: 0, y: 2)
    }
}

/// The mockup `.clabel` — a small, uppercase, letter-spaced, faint section label with an
/// optional leading SF Symbol. Used as the header of every dashboard/detail card.
struct MacCardLabel: View {
    let text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: MacTheme.s2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.macMuted)
            }
            Text(text.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.macFaint)
        }
    }
}

/// The mockup card row list: rows separated by hairline top borders (`.row` `border-top`),
/// each with a consistent 8pt-rhythm vertical padding. First row has no divider.
struct MacCardRows<Data: RandomAccessCollection, RowContent: View>: View
where Data.Element: Identifiable {
    let data: Data
    var vPadding: CGFloat = 10
    @ViewBuilder let row: (Data.Element) -> RowContent

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle().fill(Color.macBorder).frame(height: 1)
                }
                row(item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, vPadding)
            }
        }
    }
}

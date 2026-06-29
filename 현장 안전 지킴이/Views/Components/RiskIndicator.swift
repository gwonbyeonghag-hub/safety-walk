import SwiftUI
import SafetyWalkCore

// Signature visual language (DESIGN_DIRECTION §1, §4): the risk-level color system,
// expressed once as a translucent liquid-glass chip + dot. Every risk DISPLAY in the
// app routes through these so "위험" reads the same everywhere. Color is the single
// source `RiskLevel.uiColor` (low = deep gold, medium = orange, high = red); the warm
// ramp is reserved for risk meaning only — never decoration.

/// Translucent risk band/badge: liquid-glass capsule tinted by the level, with a solid
/// dot + label in the level color. Used for hazard badges, assessment bands, score result.
struct RiskChip: View {
    let level: RiskLevel
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(level.uiColor)
                .frame(width: 7, height: 7)
            Text(level.localizedLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(level.uiColor)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(level.uiColor.opacity(0.14))
                .background(.ultraThinMaterial, in: Capsule())
        }
        .overlay {
            Capsule().strokeBorder(level.uiColor.opacity(0.30), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(level.localizedLabel)
    }
}

/// Small solid risk dot for rails / distributions (home risk rail, list distribution).
struct RiskDot: View {
    let level: RiskLevel
    var size: CGFloat = 8
    var body: some View {
        Circle()
            .fill(level.uiColor)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

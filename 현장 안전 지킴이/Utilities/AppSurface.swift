import SwiftUI

/// Shared surface tokens for iOS content cards/rows, so every free-floating card
/// reads as one system (UI consolidation). macOS keeps its own tokens.
enum AppSurface {
    /// Corner radius for content cards and rows. The signature status rail keeps a
    /// larger radius on purpose (DESIGN_DIRECTION: one deliberately bold element).
    static let cornerRadius: CGFloat = 12
}

extension View {
    /// Standard free-floating content card: system-background fill + a hairline
    /// separator border at the shared radius. For cards that sit directly on the
    /// plain background (Home). Detail screens that inset sections on a `.quaternary`
    /// fill keep that idiom — same radius, no border.
    func cardSurface(cornerRadius: CGFloat = AppSurface.cornerRadius) -> some View {
        self
            .background(.background, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
    }
}

import SwiftUI
import UIKit
import CoreText

// MARK: - Wordmark vector path (Core Text)

/// Builds a single combined `Path` from the glyph outlines of a string. SwiftUI `Text`
/// cannot be reveal-masked as a vector, so the launch wordmark is rendered as a vector
/// path. `CTLine` lays glyphs out left-to-right; Core Text paths are y-up, so the
/// combined path is flipped to SwiftUI's y-down space and normalized to the origin.
enum Wordmark {
    static func path(_ text: String, font: UIFont) -> Path {
        let attr = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attr)
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        let combined = CGMutablePath()
        for run in runs {
            let a = CTRunGetAttributes(run) as NSDictionary
            let f = a[kCTFontAttributeName as String] as! CTFont
            for i in 0..<CTRunGetGlyphCount(run) {
                var g = CGGlyph(); var p = CGPoint()
                CTRunGetGlyphs(run, CFRange(location: i, length: 1), &g)
                CTRunGetPositions(run, CFRange(location: i, length: 1), &p)
                guard let gp = CTFontCreatePathForGlyph(f, g, nil) else { continue }
                combined.addPath(gp, transform: CGAffineTransform(translationX: p.x, y: p.y))
            }
        }
        let b = combined.boundingBoxOfPath
        var flip = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: -b.minX, y: -b.maxY)
        return Path(combined.copy(using: &flip) ?? combined)
    }
}

/// Scales and centers a prebuilt wordmark `Path` to fit its layout rect, preserving
/// aspect ratio. `base` is built once and injected (Core Text path construction is
/// relatively expensive).
private struct WordmarkShape: Shape {
    let base: Path
    func path(in rect: CGRect) -> Path {
        let bb = base.boundingRect
        guard bb.width > 0, bb.height > 0 else { return base }
        let s = min(rect.width / bb.width, rect.height / bb.height)
        let scaled = base.applying(CGAffineTransform(scaleX: s, y: s))
        let sb = scaled.boundingRect
        return scaled.applying(.init(translationX: rect.midX - sb.midX, y: rect.midY - sb.midY))
    }
}

// MARK: - Brand wordmark constant + prebuilt path

// "SafetyWalk" is the English brand wordmark. It is intentionally NOT localized (the KO
// app name is 현장 안전 지킴이, but the launch mark is the brand identity) and is therefore
// a deliberate, documented exception to the no-hard-coded-strings guardrail — it is not a
// user-facing localizable string.
private let brandWordmark = "SafetyWalk"

private func roundedBoldFont(ofSize size: CGFloat) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: .bold)
    guard let d = base.fontDescriptor.withDesign(.rounded) else { return base }
    return UIFont(descriptor: d, size: size)
}

// Built a single time from the glyph outlines. The absolute font size only sets the
// path's internal resolution; `WordmarkShape` rescales it to the on-screen frame.
private let wordmarkBasePath: Path = Wordmark.path(brandWordmark, font: roundedBoldFont(ofSize: 120))

// MARK: - Adaptive intro palette

// colorScheme-driven so the intro stays consistent with the app's effective appearance
// (System / Light / Dark). Orange is the brand accent and reads on both backdrops.
private let introAccentColor = Color(red: 0.93, green: 0.55, blue: 0.13)
private func introInkColor(_ s: ColorScheme) -> Color {
    s == .dark ? .white : Color(red: 0.13, green: 0.15, blue: 0.18)
}

// MARK: - Wordmark launch intro mark

/// "SafetyWalk" wordmark rendered as **filled (solid)** glyphs, revealed left-to-right by
/// a growing mask, with a brand-orange underline growing on the same progress. Ink color
/// adapts: dark ink in light mode, white in dark mode; the underline is orange in both.
private struct LaunchIntroMark: View {
    let drawProgress: CGFloat
    @Environment(\.colorScheme) private var scheme
    private let markWidth: CGFloat = 240
    private let markHeight: CGFloat = 64

    var body: some View {
        VStack(spacing: 12) {
            WordmarkShape(base: wordmarkBasePath)
                .fill(introInkColor(scheme))
                .frame(width: markWidth, height: markHeight)
                .mask(
                    HStack(spacing: 0) {
                        Rectangle().frame(width: markWidth * drawProgress)
                        Spacer(minLength: 0)
                    }
                    .frame(width: markWidth, height: markHeight)
                )

            // Brand-orange underline grows left → right with the same progress.
            ZStack(alignment: .leading) {
                Capsule().fill(introAccentColor.opacity(scheme == .dark ? 0.18 : 0.12))
                    .frame(width: markWidth, height: 3)
                Capsule().fill(introAccentColor)
                    .frame(width: max(0, markWidth * drawProgress), height: 3)
            }
            .frame(width: markWidth)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Root view

struct ContentView: View {
    @AppStorage("com.safetywalk.hasCompletedOnboarding")
    private var hasCompletedOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var showIntro = true
    @State private var contentOpacity: Double = 0
    @State private var markOpacity: Double = 0
    @State private var markScale: Double = 1.0
    @State private var drawProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            appContent.opacity(contentOpacity)
            if showIntro {
                LaunchIntroMark(drawProgress: drawProgress)
                    .opacity(markOpacity)
                    .scaleEffect(reduceMotion ? 1.0 : markScale)
            }
        }
        .onAppear(perform: runIntroOnce)
    }

    @ViewBuilder private var appContent: some View {
        if hasCompletedOnboarding { mainShell } else { OnboardingView() }
    }

    /// WO-7: iPad (regular width) → native `NavigationSplitView` shell; everything else —
    /// iPhone (any orientation) and iPad narrow multitasking (compact) — keeps the existing
    /// tab bar. Idiom-gated so an iPhone in regular-width landscape (Plus/Max) never
    /// switches to the sidebar, guaranteeing iPhone has no layout change.
    @ViewBuilder private var mainShell: some View {
        if UIDevice.current.userInterfaceIdiom == .pad && hSize == .regular {
            IPadRootView()
        } else {
            mainTabView
        }
    }

    private var mainTabView: some View {
        TabView {
            HomeView().tabItem { Label(LocalizationKey.tabHome.localized, systemImage: "house") }
            InspectionView().tabItem { Label(LocalizationKey.tabInspection.localized, systemImage: "checklist") }
            HazardsTabView().tabItem { Label(LocalizationKey.tabHazards.localized, systemImage: "exclamationmark.triangle") }
            HistoryTabView().tabItem { Label(LocalizationKey.tabHistory.localized, systemImage: "clock") }
            SettingsView().tabItem { Label(LocalizationKey.tabSettings.localized, systemImage: "gear") }
        }
    }

    // Plays once: fade in → filled letters reveal left→right (0.85s) → reveal content.
    private func runIntroOnce() {
        guard showIntro, contentOpacity == 0 else { return }
        markOpacity = 0; markScale = 1.0; drawProgress = 0; contentOpacity = 0
        if reduceMotion {
            drawProgress = 1
            withAnimation(.easeInOut(duration: 0.40)) { markOpacity = 0; contentOpacity = 1 } completion: { showIntro = false }
            return
        }
        withAnimation(.easeOut(duration: 0.12)) { markOpacity = 1 } completion: {
            withAnimation(.easeInOut(duration: 0.85)) { drawProgress = 1 } completion: {
                withAnimation(.easeInOut(duration: 0.32)) {
                    markScale = 1.06; markOpacity = 0; contentOpacity = 1
                } completion: { showIntro = false }
            }
        }
    }
}

#Preview { ContentView() }

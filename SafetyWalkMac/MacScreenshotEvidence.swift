#if DEBUG
import Foundation
import SwiftUI
import SwiftData
import AppKit
import SafetyWalkCore

/// DEBUG evidence hook (WO-6b): when launched with
/// `defaults write com.gwonbyeonghag.safetywalk.mac mac.debug.dumpScreenshots -bool true`,
/// renders the dashboard at an explicit 1440×900pt / 2x scale (App Store's 2880×1800 macOS
/// size) and writes a PNG into the app's own sandbox container
/// (`FileManager.default.temporaryDirectory` — arbitrary external paths are denied by App
/// Sandbox), then exits.
///
/// Uses a real (off-screen) `NSWindow` + `NSHostingView` + `cacheDisplay`, not
/// `ImageRenderer` — `ImageRenderer(content:).cgImage` reproducibly captured a
/// blank/background-only frame for `DashboardView` (ScrollView + LazyVGrid content never
/// laid out), even after priming renders and yielding. A real window drives AppKit's
/// actual layout engine, so ScrollView/LazyVGrid content renders exactly as it would
/// on-screen — and `cacheDisplay` rasterizes the view's own backing store directly, so
/// the window's screen position/size don't need to fit any actual display.
///
/// Not used for `ReportHubView`: its PDF preview pane is a layer-backed PDFKit view that
/// `cacheDisplay` cannot rasterize (comes back blank) — that screen needs a real, visible
/// window captured with `screencapture -l`.
enum MacScreenshotEvidence {

    @MainActor
    static func dumpIfRequested() async {
        guard UserDefaults.standard.bool(forKey: "mac.debug.dumpScreenshots") else { return }
        let outDir = FileManager.default.temporaryDirectory

        for mode in [AppearanceMode.light, .dark] {
            let dashboard = DashboardView()
                .modelContainer(MacModelContainer.shared)
                .environment(\.locale, Locale(identifier: "ko"))
                .preferredColorScheme(mode.colorScheme)
            await render(dashboard, size: CGSize(width: 1440, height: 900), scale: 2.0,
                         to: outDir.appendingPathComponent("dashboard_\(mode.rawValue).png"))
        }
        exit(0)
    }

    @MainActor
    private static func render<V: View>(_ view: V, size: CGSize, scale: CGFloat, to url: URL) async {
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        hosting.frame = CGRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        // Position far off-screen — still a real window (real layout engine), just not
        // visible to anyone. cacheDisplay rasterizes the view's own backing store, not
        // the screen framebuffer, so this doesn't need to overlap an actual display.
        window.setFrameOrigin(CGPoint(x: -20000, y: -20000))
        window.orderFrontRegardless()

        hosting.layoutSubtreeIfNeeded()
        try? await Task.sleep(nanoseconds: 500_000_000)   // let SwiftData @Query / layout settle
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        // A rep constructed at the target PIXEL size, with `.size` set to the POINT size,
        // tells `cacheDisplay` the intended scale factor (pixelsWide / size.width == 2.0
        // here) — one call rasterizes the view's real backing store at that resolution.
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            window.orderOut(nil)
            return
        }
        rep.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        window.orderOut(nil)

        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
#endif

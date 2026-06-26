import SwiftUI
import UIKit

/// Minimal SwiftUI wrapper around `UIActivityViewController` for sharing files
/// (e.g. an exported PDF) through the standard iOS share sheet.
/// No custom activities, no excluded types — let iOS show its default surface
/// (Mail, KakaoTalk, AirDrop, Files, Copy, ...).
struct ShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
        // No-op; the items array is captured at make-time.
    }
}

/// Identifiable wrapper around a file URL so callers can drive `.sheet(item:)`
/// presentation cleanly. SwiftUI sets the binding back to `nil` on dismiss,
/// which is the correct lifecycle for the temp PDF.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

import AppKit
import SafetyWalkCore

/// Builds the `NSImage` photo dictionaries the (cross-platform) `InspectionReport` needs
/// on macOS. DEBUG seed records mark a photo with `SeedData.seedPhotoMarker`; here we
/// render a simple placeholder image for each so the report's photo blocks are exercised.
/// Real synced photos decode `photoData` directly (CloudKit CKAsset, WO-3).
enum MacReportPhotos {

    @MainActor
    static func photos(for inspection: Inspection) -> (items: [UUID: NSImage], hazards: [UUID: NSImage]) {
        var items: [UUID: NSImage] = [:]
        for item in (inspection.items ?? []) {
            guard let data = item.photoData else { continue }
            items[item.id] = NSImage(data: data) ?? placeholder(tint: .systemTeal, caption: "PHOTO")
        }
        var hazards: [UUID: NSImage] = [:]
        for hazard in (inspection.hazards ?? []) {
            guard let data = hazard.photoData else { continue }
            hazards[hazard.id] = NSImage(data: data) ?? placeholder(tint: color(for: hazard.riskLevel), caption: "HAZARD")
        }
        return (items, hazards)
    }

    private static func color(for level: RiskLevel) -> NSColor {
        switch level {
        case .low:    return NSColor(calibratedRed: 0.70, green: 0.52, blue: 0.00, alpha: 1)
        case .medium: return .systemOrange
        case .high:   return .systemRed
        }
    }

    private static func placeholder(tint: NSColor, caption: String) -> NSImage {
        let size = NSSize(width: 320, height: 220)
        let image = NSImage(size: size)
        image.lockFocus()
        tint.withAlphaComponent(0.18).setFill()
        NSRect(origin: .zero, size: size).fill()
        tint.setStroke()
        let border = NSBezierPath(rect: NSRect(x: 4, y: 4, width: size.width - 8, height: size.height - 8))
        border.lineWidth = 2
        border.stroke()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: tint,
        ]
        let text = caption as NSString
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                  withAttributes: attrs)
        image.unlockFocus()
        return image
    }
}

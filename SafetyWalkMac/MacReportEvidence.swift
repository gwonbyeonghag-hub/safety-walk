#if DEBUG
import Foundation
import SwiftData
import SafetyWalkCore

/// DEBUG evidence hook: when launched with
/// `defaults write com.safetywalk.macos mac.debug.dumpReports <dir>` set, the app renders
/// all three reports from the seeded data (exercising the macOS `NSImage` photo path) into
/// that directory and exits. Proves the shared WO-5b engine paginates on macOS.
enum MacReportEvidence {

    @MainActor
    static func dumpIfRequested() {
        guard let dir = UserDefaults.standard.string(forKey: "mac.debug.dumpReports") else { return }
        let fm = FileManager.default
        let outDir = URL(fileURLWithPath: dir, isDirectory: true)
        try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)

        let ctx = MacModelContainer.shared.mainContext
        let ras = (try? ctx.fetch(FetchDescriptor<RiskAssessment>())) ?? []
        let insps = (try? ctx.fetch(FetchDescriptor<Inspection>())) ?? []

        func copy(_ src: URL?, to name: String) {
            guard let src else { return }
            let dst = outDir.appendingPathComponent(name)
            try? fm.removeItem(at: dst)
            try? fm.copyItem(at: src, to: dst)
        }

        if let ra = ras.first(where: { $0.method == .frequencySeverity }) ?? ras.first {
            copy(RiskAssessmentReport.pdfURL(for: ra), to: "mac_ra_table.pdf")
        }
        if let jsa = ras.first(where: { $0.method == .jsa }) {
            copy(JHAReport.pdfURL(for: jsa), to: "mac_jha.pdf")
        }
        if let insp = insps.first(where: { $0.status == .completed && !($0.items ?? []).isEmpty }) {
            let photos = MacReportPhotos.photos(for: insp)
            copy(InspectionReport.pdfURL(inspection: insp, itemPhotos: photos.items, hazardPhotos: photos.hazards),
                 to: "mac_inspection.pdf")
        }
        exit(0)
    }
}
#endif

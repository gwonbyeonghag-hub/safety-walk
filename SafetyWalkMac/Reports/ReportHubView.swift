import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import SafetyWalkCore

/// Report hub (WO-4 ④): pick an assessment/inspection, preview the generated PDF (the
/// shared WO-5b cross-platform engine), then export or print. 위험성평가표 (A4) · JHA
/// (Letter) · 점검 리포트 — the same engine the iOS app uses, on the big screen.
struct ReportHubView: View {
    @Query private var assessments: [RiskAssessment]
    @Query private var inspections: [Inspection]

    @State private var selection: String?
    @State private var currentURL: URL?

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selection) {
                Section(LocalizationKey.macAssessmentReports.localized) {
                    ForEach(assessmentEntries) { entry in row(entry).tag(entry.id) }
                }
                Section(LocalizationKey.macInspectionReports.localized) {
                    ForEach(inspectionEntries) { entry in row(entry).tag(entry.id) }
                }
            }
            .listStyle(.sidebar)
            .tint(Color.macAccent)
            .frame(width: 320)

            Divider()

            preview
                .background(Color.macBg)
        }
        .navigationTitle(LocalizationKey.macSectionReports.localized)
        .onAppear { if selection == nil { selection = assessmentEntries.first?.id } }
        .onChange(of: selection) { _, _ in regenerate() }
        .task(id: selection) { regenerate() }
    }

    // MARK: - Preview pane

    @ViewBuilder
    private var preview: some View {
        if let url = currentURL {
            VStack(spacing: 0) {
                PDFPreview(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        ReportPrinter.print(url: url)
                    } label: { Label(LocalizationKey.macPrint.localized, systemImage: "printer") }
                    Button {
                        export(url)
                    } label: { Label(LocalizationKey.macExportPDF.localized, systemImage: "square.and.arrow.down") }
                }
            }
        } else {
            ContentUnavailableView(LocalizationKey.macChooseReport.localized, systemImage: "doc.text")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Entries

    private var assessmentEntries: [ReportEntry] {
        var out: [ReportEntry] = []
        for ra in assessments.sorted(by: { $0.assessedAt > $1.assessedAt }) {
            let site = ra.siteName.isEmpty ? ra.method.localizedLabel : ra.siteName
            if ra.method == .jsa {
                out.append(ReportEntry(id: "jha-\(ra.id)", title: LocalizationKey.reportJhaTitle.localized,
                                       subtitle: site, kind: .jha, assessment: ra, inspection: nil))
            } else {
                out.append(ReportEntry(id: "ra-\(ra.id)", title: LocalizationKey.reportRaTitle.localized,
                                       subtitle: "\(site) · \(ra.method.localizedLabel)",
                                       kind: .assessmentTable, assessment: ra, inspection: nil))
            }
        }
        return out
    }

    private var inspectionEntries: [ReportEntry] {
        inspections.filter { $0.status == .completed }
            .sorted { $0.startedAt > $1.startedAt }
            .map { insp in
                ReportEntry(id: "insp-\(insp.id)", title: LocalizationKey.reportInspectionTitle.localized,
                            subtitle: "\(insp.siteName) · \(insp.areaName ?? "")",
                            kind: .inspection, assessment: nil, inspection: insp)
            }
    }

    private func row(_ entry: ReportEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.macInk)
            Text(entry.subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.macMuted)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private var allEntries: [ReportEntry] { assessmentEntries + inspectionEntries }

    // MARK: - Generation

    private func regenerate() {
        guard let id = selection, let entry = allEntries.first(where: { $0.id == id }) else {
            currentURL = nil; return
        }
        currentURL = makeURL(entry)
    }

    @MainActor
    private func makeURL(_ entry: ReportEntry) -> URL? {
        switch entry.kind {
        case .assessmentTable:
            return entry.assessment.flatMap { RiskAssessmentReport.pdfURL(for: $0) }
        case .jha:
            return entry.assessment.flatMap { JHAReport.pdfURL(for: $0) }
        case .inspection:
            guard let insp = entry.inspection else { return nil }
            let photos = MacReportPhotos.photos(for: insp)
            return InspectionReport.pdfURL(inspection: insp, itemPhotos: photos.items, hazardPhotos: photos.hazards)
        }
    }

    private func export(_ url: URL) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = url.lastPathComponent
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let dest = panel.url {
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: url, to: dest)
        }
    }
}

enum ReportKind { case assessmentTable, jha, inspection }

struct ReportEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let kind: ReportKind
    let assessment: RiskAssessment?
    let inspection: Inspection?
}

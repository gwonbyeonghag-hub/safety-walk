import XCTest
import SwiftData
import UIKit
import PDFKit
import SafetyWalkCore
@testable import 현장_안전_지킴이

/// WO-5b: renders each report to a real PDF, asserts multi-page pagination, and attaches
/// every page as an image for visual review. Uses XCTest for XCTAttachment.
@MainActor
final class ReportRenderingTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    /// Rasterizes each PDF page (UIKit, test-only) and attaches it; returns page count.
    @discardableResult
    private func attachPages(_ url: URL, name: String) -> Int {
        guard let doc = CGPDFDocument(url as CFURL) else { XCTFail("no PDF at \(url)"); return 0 }
        for i in 1...max(doc.numberOfPages, 1) {
            guard let page = doc.page(at: i) else { continue }
            let rect = page.getBoxRect(.mediaBox)
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
            let image = UIGraphicsImageRenderer(size: rect.size, format: fmt).image { ctx in
                UIColor.white.set(); ctx.fill(CGRect(origin: .zero, size: rect.size))
                let cg = ctx.cgContext
                cg.translateBy(x: 0, y: rect.size.height); cg.scaleBy(x: 1, y: -1)
                cg.drawPDFPage(page)
            }
            let a = XCTAttachment(image: image)
            a.name = "\(name)_p\(i)"; a.lifetime = .keepAlways; add(a)
        }
        return doc.numberOfPages
    }

    func testRiskAssessmentReportMultiPage() throws {
        let ctx = try makeContext()
        let assessment = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                        siteId: UUID(), siteName: "○○건설 1현장", assessorName: "홍길동")
        ctx.insert(assessment)
        var items: [RiskAssessmentItem] = []
        for i in 0..<28 {
            let l = (i % 3) + 1, s = ((i + 1) % 3) + 1
            let level = RiskMatrixConfig.threeByThree.band(likelihood: l, severity: s)
            let item = RiskAssessmentItem(
                taskDescription: "공정 \(i + 1) — 작업 단계 기록",
                hazardDescription: "유해·위험요인 상세 설명 \(i + 1)",
                currentControls: "현재 안전조치 \(i + 1)",
                likelihood: l, severity: s, riskLevel: level, sortOrder: i)
            ctx.insert(item)
            // Improvement fields live on CorrectiveAction (SCHEMA_V3 §4); the report renders the
            // reduction/owner/status columns from the item's 1:N corrective actions (WO LEGAL-2c).
            let action = try CorrectiveActionPolicy.makeDraft(item: item, measure: "감소대책 항목 \(i + 1)",
                                              responsibleName: "담당\(i + 1)", dueDate: Date())
            ctx.insert(action)
            items.append(item)
        }
        assessment.items = items
        try? ctx.save()

        let url = try XCTUnwrap(RiskAssessmentReport.pdfURL(for: assessment), "report URL nil")
        let pages = attachPages(url, name: "risk_assessment")
        XCTAssertGreaterThanOrEqual(pages, 2, "28 rows should paginate to ≥2 A4 pages")
    }

    func testJHAReportMultiPage() throws {
        let ctx = try makeContext()
        let assessment = RiskAssessment(kind: .regular, method: .jsa,
                                        siteId: UUID(), siteName: "Plant A — Line 2", assessorName: "J. Park")
        ctx.insert(assessment)
        var items: [RiskAssessmentItem] = []
        for i in 0..<22 {
            let l = (i % 3) + 1, s = ((i + 2) % 3) + 1
            let level = RiskMatrixConfig.threeByThree.band(likelihood: l, severity: s)
            let item = RiskAssessmentItem(
                taskDescription: "Job step \(i + 1): position and secure equipment",
                hazardDescription: "Pinch point / falling object hazard \(i + 1)",
                currentControls: "LOTO; barricade exclusion zone \(i + 1)",
                likelihood: l, severity: s, riskLevel: level, sortOrder: i)
            ctx.insert(item)
            let action = try CorrectiveActionPolicy.makeDraft(item: item, measure: "Add spotter; PPE check \(i + 1)")
            ctx.insert(action)
            items.append(item)
        }
        assessment.items = items
        try? ctx.save()

        let url = try XCTUnwrap(JHAReport.pdfURL(for: assessment), "JHA URL nil")
        let pages = attachPages(url, name: "jha")
        XCTAssertGreaterThanOrEqual(pages, 2, "22 steps should paginate to ≥2 Letter pages")
    }

    func testInspectionReportMultiPage() throws {
        let ctx = try makeContext()
        let insp = Inspection(siteId: UUID(), siteName: "○○현장", areaName: "1층 전기실",
                              inspectorName: "김점검", templateId: "t")
        insp.status = .completed
        ctx.insert(insp)

        var items: [ChecklistItem] = []
        var order = 0
        for category in ["checklist.category.electrical", "checklist.category.fire", "checklist.category.ppe"] {
            for j in 0..<9 {
                let item = ChecklistItem(inspectionId: insp.id, templateItemId: "t\(order)",
                                         title: "점검 항목 \(order + 1)", category: category, sortOrder: order)
                item.result = j % 3 == 0 ? .fail : (j % 3 == 1 ? .pass : .notApplicable)
                if j == 0 { item.note = "비고: 추가 확인 필요 \(order)" }
                ctx.insert(item); items.append(item); insp.items?.append(item); order += 1
            }
        }

        let photo = dummyImage()
        var hazardPhotos: [UUID: UIImage] = [:]
        for k in 0..<4 {
            let level: RiskLevel = [.low, .medium, .high][k % 3]
            let hazard = Hazard(siteId: insp.siteId, location: "위치 \(k)", type: .electrical,
                                riskLevel: level, hazardDescription: "유해위험요인 설명 \(k)",
                                photoData: Data("p\(k)".utf8), inspectionId: insp.id)
            ctx.insert(hazard); insp.hazards?.append(hazard); hazardPhotos[hazard.id] = photo
        }
        var itemPhotos: [UUID: UIImage] = [:]
        for item in items where item.sortOrder % 9 == 0 { itemPhotos[item.id] = photo }
        try? ctx.save()

        let url = try XCTUnwrap(
            InspectionReport.pdfURL(inspection: insp, itemPhotos: itemPhotos, hazardPhotos: hazardPhotos),
            "inspection report URL nil")
        let pages = attachPages(url, name: "inspection")
        XCTAssertGreaterThanOrEqual(pages, 2, "27 items + photos + hazards should paginate to ≥2 pages")
    }

    // MARK: - WO LEGAL-2c 반송 4차 P1: 1:N 개선조치가 페이지에 걸쳐 잘리지 않고 모두 보존되는지

    /// Extracts the selectable text of every page (PDFKit) so we can assert no action was clipped.
    private func extractText(_ url: URL) -> String {
        guard let doc = PDFDocument(url: url) else { return "" }
        return (0..<doc.pageCount).compactMap { doc.page(at: $0)?.string }.joined(separator: "\n")
    }

    /// One item carrying many corrective actions must paginate across pages with EVERY action
    /// preserved — the whole 1:N set can't be trapped in a single unsplittable block.
    func testRiskAssessmentReportPreservesEveryActionAcrossPages() throws {
        let ctx = try makeContext()
        let assessment = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                        siteId: UUID(), siteName: "○○건설 1현장", assessorName: "홍길동")
        ctx.insert(assessment)
        let item = RiskAssessmentItem(
            taskDescription: "고소 작업 — 외부 비계 설치",
            hazardDescription: "추락·낙하물 위험",
            currentControls: "안전난간 설치",
            likelihood: 3, severity: 3, riskLevel: .high, sortOrder: 0)
        ctx.insert(item)

        var markers: [String] = []
        for i in 0..<28 {
            let marker = String(format: "MRK%02d", i)
            markers.append(marker)
            let action = try CorrectiveActionPolicy.makeDraft(
                item: item,
                measure: "감소대책 안전대 착용 및 안전난간 보강 점검 실시 [\(marker)]",
                responsibleName: "담당\(i)", dueDate: Date())
            ctx.insert(action)
        }
        assessment.items = [item]
        try? ctx.save()

        let url = try XCTUnwrap(RiskAssessmentReport.pdfURL(for: assessment), "report URL nil")
        let pages = attachPages(url, name: "risk_actions_overflow")
        XCTAssertGreaterThanOrEqual(pages, 2, "one item with \(markers.count) actions must span ≥2 A4 pages")

        let text = extractText(url)
        XCTAssertTrue(text.contains(markers.first!), "sanity: first action must render (text extraction works)")
        let missing = markers.filter { !text.contains($0) }
        XCTAssertTrue(missing.isEmpty, "no action may be truncated — missing: \(missing)")
        for m in markers {
            XCTAssertEqual(text.components(separatedBy: m).count - 1, 1, "\(m) must appear exactly once (no duplication)")
        }
    }

    /// Same guarantee for the JHA sheet — actions must not be collapsed into one merged controls cell.
    func testJHAReportPreservesEveryActionAcrossPages() throws {
        let ctx = try makeContext()
        let assessment = RiskAssessment(kind: .regular, method: .jsa,
                                        siteId: UUID(), siteName: "Plant A — Line 2", assessorName: "J. Park")
        ctx.insert(assessment)
        let item = RiskAssessmentItem(
            taskDescription: "Erect exterior scaffold at height",
            hazardDescription: "Fall / falling-object hazard",
            currentControls: "Guardrail installed",
            likelihood: 3, severity: 3, riskLevel: .high, sortOrder: 0)
        ctx.insert(item)

        var markers: [String] = []
        for i in 0..<28 {
            let marker = String(format: "MRK%02d", i)
            markers.append(marker)
            let action = try CorrectiveActionPolicy.makeDraft(
                item: item,
                measure: "Add spotter, verify anchor points and inspect PPE before work [\(marker)]",
                responsibleName: "Owner \(i)")
            ctx.insert(action)
        }
        assessment.items = [item]
        try? ctx.save()

        let url = try XCTUnwrap(JHAReport.pdfURL(for: assessment), "JHA URL nil")
        let pages = attachPages(url, name: "jha_actions_overflow")
        XCTAssertGreaterThanOrEqual(pages, 2, "one step with \(markers.count) actions must span ≥2 Letter pages")

        let text = extractText(url)
        XCTAssertTrue(text.contains(markers.first!), "sanity: first action must render (text extraction works)")
        let missing = markers.filter { !text.contains($0) }
        XCTAssertTrue(missing.isEmpty, "no action may be truncated — missing: \(missing)")
        for m in markers {
            XCTAssertEqual(text.components(separatedBy: m).count - 1, 1, "\(m) must appear exactly once (no duplication)")
        }
    }

    // MARK: - WO LEGAL-2c 5차 P1: 조치 행이 그 자체로 부모 항목을 식별할 수 있는가

    /// Per-page selectable text (PDFKit) — page-boundary claims need per-page, not whole-document, text.
    private func pageTexts(_ url: URL) -> [String] {
        guard let doc = PDFDocument(url: url) else { return [] }
        return (0..<doc.pageCount).map { doc.page(at: $0)?.string ?? "" }
    }

    /// Asserts the report's core 1:N guarantees plus per-page traceability: on EVERY page that shows a
    /// corrective action, the parent item's task/hazard identifiers must be on that same page. A reader
    /// holding page 2 alone must still be able to tell which 항목 those 개선조치 belong to.
    private func assertActionsTraceablePerPage(
        url: URL, markers: [String], taskMarker: String, hazardMarker: String,
        minPages: Int = 2, file: StaticString = #filePath, line: UInt = #line
    ) {
        let pages = pageTexts(url)
        XCTAssertGreaterThanOrEqual(pages.count, minPages,
            "one item with \(markers.count) actions must span ≥\(minPages) pages", file: file, line: line)

        let whole = pages.joined(separator: "\n")
        let missing = markers.filter { !whole.contains($0) }
        XCTAssertTrue(missing.isEmpty, "no action may be truncated — missing: \(missing)", file: file, line: line)
        for m in markers {
            XCTAssertEqual(whole.components(separatedBy: m).count - 1, 1,
                           "\(m) must appear exactly once (no duplication)", file: file, line: line)
        }

        for (index, text) in pages.enumerated() {
            let actionsHere = markers.filter { text.contains($0) }
            guard !actionsHere.isEmpty else { continue }
            XCTAssertTrue(text.contains(taskMarker),
                "page \(index + 1) renders actions \(actionsHere) but carries no parent task identifier",
                file: file, line: line)
            XCTAssertTrue(text.contains(hazardMarker),
                "page \(index + 1) renders actions \(actionsHere) but carries no parent hazard identifier",
                file: file, line: line)
        }
    }

    func testRiskAssessmentReportKeepsItemIdentityOnEveryActionPage() throws {
        let ctx = try makeContext()
        let assessment = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                        siteId: UUID(), siteName: "○○건설 1현장", assessorName: "홍길동")
        ctx.insert(assessment)
        let item = RiskAssessmentItem(
            taskDescription: "고소 작업 TSKMRK 외부 비계 설치",
            hazardDescription: "추락·낙하물 위험 HAZMRK",
            currentControls: "안전난간 설치",
            likelihood: 3, severity: 3, riskLevel: .high, sortOrder: 0)
        ctx.insert(item)

        var markers: [String] = []
        for i in 0..<28 {
            let marker = String(format: "MRK%02d", i)
            markers.append(marker)
            let action = try CorrectiveActionPolicy.makeDraft(
                item: item,
                measure: "감소대책 안전대 착용 및 안전난간 보강 [\(marker)]",
                responsibleName: "담당\(i)", dueDate: Date())
            ctx.insert(action)
        }
        assessment.items = [item]
        try? ctx.save()

        let url = try XCTUnwrap(RiskAssessmentReport.pdfURL(for: assessment), "report URL nil")
        attachPages(url, name: "risk_actions_traceable")
        assertActionsTraceablePerPage(url: url, markers: markers,
                                      taskMarker: "TSKMRK", hazardMarker: "HAZMRK")
    }

    func testJHAReportKeepsStepIdentityOnEveryActionPage() throws {
        let ctx = try makeContext()
        let assessment = RiskAssessment(kind: .regular, method: .jsa,
                                        siteId: UUID(), siteName: "Plant A — Line 2", assessorName: "J. Park")
        ctx.insert(assessment)
        let item = RiskAssessmentItem(
            taskDescription: "Erect exterior scaffold TSKMRK",
            hazardDescription: "Fall / falling-object hazard HAZMRK",
            currentControls: "Guardrail installed",
            likelihood: 3, severity: 3, riskLevel: .high, sortOrder: 0)
        ctx.insert(item)

        var markers: [String] = []
        for i in 0..<28 {
            let marker = String(format: "MRK%02d", i)
            markers.append(marker)
            let action = try CorrectiveActionPolicy.makeDraft(
                item: item,
                measure: "Add spotter, verify anchors, inspect PPE [\(marker)]",
                responsibleName: "Owner \(i)")
            ctx.insert(action)
        }
        assessment.items = [item]
        try? ctx.save()

        let url = try XCTUnwrap(JHAReport.pdfURL(for: assessment), "JHA URL nil")
        attachPages(url, name: "jha_actions_traceable")
        assertActionsTraceablePerPage(url: url, markers: markers,
                                      taskMarker: "TSKMRK", hazardMarker: "HAZMRK")
    }

    private func dummyImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 320, height: 220)).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 320, height: 220))
        }
    }
}

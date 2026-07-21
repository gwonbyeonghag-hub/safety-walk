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

    // MARK: - WO LEGAL-2c 마감: JHA Controls 열의 행 의미(현재 안전조치 / 감소대책) 구분

    /// The JHA Controls column carries two different kinds of row — the step's EXISTING controls and each
    /// RECOMMENDED 감소대책. The column header (`report.jha.controls`) covers both, so only a per-row label
    /// tells them apart; without it a reader on page 2 can't tell an in-place control from a proposal.
    /// Locale-agnostic: the test host may render either language, so either form counts.
    private func occurrences(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// PDFKit splits a page into text runs and can insert whitespace or a line break between them, so a
    /// multi-word label ("현재 안전조치", "Current Controls") may come back with its inner spacing altered.
    /// Matching on whitespace-stripped text keeps the assertion about the LABEL rather than about
    /// PDFKit's run segmentation — the label characters must still all be present, in order.
    private func despaced(_ s: String) -> String {
        s.components(separatedBy: .whitespacesAndNewlines).joined()
    }

    private func labelHits(_ forms: [String], in text: String) -> Int {
        let haystack = despaced(text)
        return forms.map { occurrences(despaced($0), in: haystack) }.reduce(0, +)
    }

    func testJHAReportLabelsCurrentControlsAndReductionMeasureRows() throws {
        let currentControlsForms = ["현재 안전조치", "Current Controls"]
        let reductionForms = ["감소대책", "Reduction Measure"]

        let ctx = try makeContext()
        let assessment = RiskAssessment(kind: .regular, method: .jsa,
                                        siteId: UUID(), siteName: "Plant A — Line 2", assessorName: "J. Park")
        ctx.insert(assessment)
        // NOTE: neither the controls text nor any measure may contain a label word, or the assertions
        // below would pass on the payload instead of on the label the renderer is supposed to add.
        let item = RiskAssessmentItem(
            taskDescription: "Erect exterior scaffold TSKMRK",
            hazardDescription: "Fall / falling-object hazard HAZMRK",
            currentControls: "Guardrail installed CTLMRK",
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
        attachPages(url, name: "jha_controls_labelled")

        let pages = pageTexts(url)
        XCTAssertGreaterThanOrEqual(pages.count, 2, "28 actions must span ≥2 pages")

        let whole = pages.joined(separator: "\n")
        let missing = markers.filter { !whole.contains($0) }
        XCTAssertTrue(missing.isEmpty, "no action may be truncated — missing: \(missing)")
        for m in markers {
            XCTAssertEqual(occurrences(m, in: whole), 1, "\(m) must appear exactly once")
        }

        // The step's existing controls must be labelled as such, on the page where they render.
        // The sanity check is load-bearing: the loop below is filtered on CTLMRK, so if the renderer ever
        // dropped the current-controls value entirely the loop body would never run and pass vacuously.
        XCTAssertTrue(whole.contains("CTLMRK"), "sanity: the step's current controls must render at all")
        for (index, text) in pages.enumerated() where text.contains("CTLMRK") {
            XCTAssertGreaterThanOrEqual(labelHits(currentControlsForms, in: text), 1,
                "page \(index + 1) shows the step's current controls without a 현재 안전조치 / Current Controls label")
        }

        // EVERY action row — including ones that open page 2 or 3 — must be labelled 감소대책, one label
        // per action row (a single stray occurrence must not satisfy a page holding many actions).
        for (index, text) in pages.enumerated() {
            let actionsHere = markers.filter { text.contains($0) }
            guard !actionsHere.isEmpty else { continue }
            XCTAssertGreaterThanOrEqual(labelHits(reductionForms, in: text), actionsHere.count,
                "page \(index + 1) renders \(actionsHere.count) action rows but only "
                + "\(labelHits(reductionForms, in: text)) 감소대책 / Reduction Measure labels")
        }
    }

    /// An empty Controls value must read as 미기록 / Not recorded — not a bare literal dash.
    func testJHAReportUsesNotRecordedForEmptyControls() throws {
        let ctx = try makeContext()
        let assessment = RiskAssessment(kind: .regular, method: .jsa,
                                        siteId: UUID(), siteName: "Plant B", assessorName: "J. Park")
        ctx.insert(assessment)
        let item = RiskAssessmentItem(
            taskDescription: "Step with no recorded controls NOCTL",
            hazardDescription: "Pinch point",
            currentControls: nil,
            likelihood: 2, severity: 2, riskLevel: .medium, sortOrder: 0)
        ctx.insert(item)
        assessment.items = [item]
        try? ctx.save()

        let url = try XCTUnwrap(JHAReport.pdfURL(for: assessment), "JHA URL nil")
        let whole = pageTexts(url).joined(separator: "\n")

        XCTAssertTrue(whole.contains("NOCTL"), "sanity: the step must render")
        XCTAssertGreaterThanOrEqual(labelHits(["미기록", "Not recorded"], in: whole), 1,
            "an empty Controls value must render the shared 미기록 / Not recorded label")
    }

    // MARK: - WO LEGAL-2e: PDF 에 공유 이력 + 3년 보존 안내가 실제로 렌더되는지 (값 스냅샷 아님 —
    // SharingEvent 모델 필드만 사용, 참여자 개인정보는 포함하지 않는다)

    func testRiskAssessmentReportIncludesSharingHistoryAndRetentionNotice() throws {
        let ctx = try makeContext()
        let assessment = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                        siteId: UUID(), siteName: "○○건설 1현장", assessorName: "홍길동")
        assessment.scheduledAt = Date()   // 사전 공유 기록의 전제(SharingEventPolicy)
        ctx.insert(assessment)
        let item = RiskAssessmentItem(
            taskDescription: "굴착 작업 PDFMRK", hazardDescription: "붕괴 위험",
            likelihood: 1, severity: 1, riskLevel: .low, sortOrder: 0)
        ctx.insert(item)
        assessment.items = [item]
        try ctx.save()

        try SharingEventRecording.record(
            phase: .pre, method: .posting, in: assessment,
            target: "정문 게시판 SHRTGT", ownerName: "홍길동 SHROWN", at: Date(), context: ctx)

        let url = try XCTUnwrap(RiskAssessmentReport.pdfURL(for: assessment), "report URL nil")
        attachPages(url, name: "risk_sharing_retention")
        let whole = pageTexts(url).joined(separator: "\n")

        XCTAssertTrue(whole.contains("SHRTGT"), "recorded sharing target must render in the PDF")
        XCTAssertTrue(whole.contains("SHROWN"), "recorded sharing owner must render in the PDF")
        XCTAssertGreaterThanOrEqual(labelHits(["구분", "Phase"], in: whole), 1,
            "sharing-history column header must render")
        XCTAssertTrue(whole.contains(assessment.retainUntilDisplayText),
            "the computed retainUntil date must render in the PDF")
        XCTAssertGreaterThanOrEqual(labelHits(["보존 기한", "Retention until"], in: whole), 1,
            "retention label must render")
    }

    /// 공유 기록이 없으면 "미기록" 이 아니라 빈 이력 안내 문구가 렌더된다(nil=미기록 오용 금지).
    func testRiskAssessmentReportShowsEmptySharingHistoryMessageWhenNoRecords() throws {
        let ctx = try makeContext()
        let assessment = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                        siteId: UUID(), siteName: "Plant B", assessorName: "홍길동")
        ctx.insert(assessment)
        try ctx.save()

        let url = try XCTUnwrap(RiskAssessmentReport.pdfURL(for: assessment), "report URL nil")
        let whole = pageTexts(url).joined(separator: "\n")

        XCTAssertGreaterThanOrEqual(labelHits(["아직 공유 기록이 없습니다", "No sharing records yet"], in: whole), 1,
            "an assessment with no sharing history must show the shared empty-state message")
    }

    // MARK: - WO LEGAL-TBM-3: 브리핑 PDF — 값 스냅샷 기반, 참석자 PII 미포함(집계만)

    /// BriefingParticipant/BriefingRiskItemSnapshot 의 생성자는 SafetyWalkCore 패키지 내부
    /// 전용이라(WO LEGAL-TBM-1 §4 "sealed로 Core 우회 불가") 앱 레벨 테스트는 실제 Core 원자
    /// 연산 체인(create→conduct→participant 추가→finalize)으로만 픽스처를 만들 수 있다 — 화면이
    /// 쓰는 것과 같은 경로라 렌더 대상이 실제 상태에 더 가깝다.
    private func finalizedBriefingWithSnapshotAndParticipant(
        in ctx: ModelContext, participantName: String
    ) throws -> SafetyBriefing {
        let assessment = try AssessmentAuthoring.create(
            AssessmentDraft(kind: .regular, method: .frequencySeverity,
                            siteId: UUID(), siteName: "○○건설 1현장", assessorName: "홍길동",
                            items: [AssessmentDraft.ItemDraft(
                                taskDescription: "굴착 작업 PDFMRK", hazardDescription: "붕괴 위험 HAZMRK",
                                currentControls: "표지판 설치",
                                likelihood: 3, severity: 3, riskLevel: .high,
                                measure: "안전난간 설치 MEASUREMRK", responsibleName: "김담당")]),
            now: Date(), in: ctx)

        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "○○건설 1현장", assessmentId: assessment.id,
                         taskDescription: "굴착 작업 TASKMRK", occurredAt: Date(), location: "A동 1층"),
            in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "전달내용 CONTENTMRK",
                                      sourceAssessment: assessment, now: Date(), in: ctx)
        try BriefingParticipantEditing.add(to: briefing, name: participantName, role: .worker,
                                           at: Date(), context: ctx)
        try BriefingLifecycle.finalize(briefing, now: Date(), in: ctx)
        return briefing
    }

    func testSafetyBriefingReportRendersContentRiskSnapshotAndAttendanceSummary() throws {
        let ctx = try makeContext()
        let briefing = try finalizedBriefingWithSnapshotAndParticipant(in: ctx, participantName: "홍길동")

        let url = try XCTUnwrap(SafetyBriefingReport.pdfURL(for: briefing), "briefing report URL nil")
        attachPages(url, name: "briefing_report")
        let whole = pageTexts(url).joined(separator: "\n")

        XCTAssertTrue(whole.contains("○○건설 1현장"), "site must render")
        // PDFKit 은 CJK+라틴 혼합 텍스트를 run 여러 개로 쪼개며 그 사이에 공백/줄바꿈을 끼워 넣을 수
        // 있다(파일 상단 despaced() 주석 참고) — 라벨 매칭과 같은 방식으로 공백을 제거하고 비교한다.
        XCTAssertTrue(despaced(whole).contains(despaced("굴착 작업 TASKMRK")), "briefing task description must render")
        XCTAssertTrue(whole.contains("전달내용 CONTENTMRK"), "briefing content (locked at conduct) must render")
        XCTAssertTrue(whole.contains("PDFMRK"), "the value-copied risk snapshot's task must render")
        XCTAssertTrue(whole.contains("HAZMRK"), "the value-copied risk snapshot's hazard must render")
        XCTAssertTrue(whole.contains("MEASUREMRK"),
            "the snapshot's 1:N control measure must render (SCHEMA_V3 §4 '문자열 축약 금지')")
        XCTAssertGreaterThanOrEqual(labelHits(["참석 요약", "Attendance Summary"], in: whole), 1,
            "attendance summary section must render")
        XCTAssertTrue(whole.contains("1"), "attendance count (1 participant) must render somewhere")
    }

    /// ★ 핵심 회귀 가드 — WO LEGAL-TBM-3 §3: 브리핑 PDF는 참석자 이름·서명(제3자 PII)을 포함하지
    /// 않는다(2e 결정과 일관, 기본값). 참석 요약은 집계만 렌더한다.
    func testSafetyBriefingReportExcludesParticipantPII() throws {
        let ctx = try makeContext()
        let briefing = try finalizedBriefingWithSnapshotAndParticipant(in: ctx, participantName: "김철수PIINAME")

        let url = try XCTUnwrap(SafetyBriefingReport.pdfURL(for: briefing), "briefing report URL nil")
        let whole = pageTexts(url).joined(separator: "\n")

        XCTAssertFalse(whole.contains("김철수PIINAME"),
            "participant name must NOT appear in the exported PDF (PII exclusion, WO LEGAL-TBM-3 §3)")
    }

    /// standalone(연결 평가 없음) + draft 브리핑 — 위험 항목·참석자 모두 빈 상태로 안전하게 렌더된다.
    func testSafetyBriefingReportShowsEmptyStatesForStandaloneDraftBriefing() throws {
        let ctx = try makeContext()
        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "Plant B"), in: ctx)

        let url = try XCTUnwrap(SafetyBriefingReport.pdfURL(for: briefing), "briefing report URL nil")
        let whole = pageTexts(url).joined(separator: "\n")

        XCTAssertGreaterThanOrEqual(labelHits(["기록된 위험 항목이 없습니다", "No risk items recorded"], in: whole), 1,
            "an unconducted briefing must show the shared empty risk-snapshot message")
    }

    private func dummyImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 320, height: 220)).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 320, height: 220))
        }
    }
}

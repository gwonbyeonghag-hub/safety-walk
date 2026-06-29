import SwiftUI
import CoreGraphics

// Cross-platform multi-page PDF engine (WO-5b). SwiftUI `ImageRenderer` draws into a
// Core Graphics PDF context — NO UIKit (`UIGraphicsPDFRenderer`), so macOS (WO-4) reuses
// this verbatim. A report is a repeated masthead + a body block array + a repeated footer
// (page n/k). Blocks are measured and packed into pages by available height so a table
// row is never sliced across a page boundary.

enum ReportPaper {
    /// 72 dpi points. A4 = 595×842 (KR), US Letter = 612×792.
    static let a4 = CGSize(width: 595, height: 842)
    static let usLetter = CGSize(width: 612, height: 792)
}

@MainActor
enum ReportRenderer {

    /// Paginates `blocks` under a repeated `masthead` and a `footer(page, total)` and
    /// writes a multi-page PDF to `url`. Returns false if the PDF context can't be made.
    static func renderPDF(
        to url: URL,
        pageSize: CGSize,
        margin: CGFloat = 36,
        gap: CGFloat = 8,
        masthead: AnyView,
        subhead: AnyView? = nil,
        footer: (_ page: Int, _ total: Int) -> AnyView,
        blocks: [AnyView]
    ) -> Bool {
        let contentWidth = pageSize.width - margin * 2
        let mastheadHeight = measuredHeight(masthead, width: contentWidth)
        let subheadHeight = subhead.map { measuredHeight($0, width: contentWidth) + gap } ?? 0
        let footerHeight = measuredHeight(footer(1, 1), width: contentWidth)
        let available = pageSize.height - margin * 2 - mastheadHeight - subheadHeight - footerHeight - gap * 2

        // Greedy pack: keep adding blocks until the next would overflow the body area.
        // A block taller than a full page still gets its own page (alone) rather than
        // being split — true for our table rows, which are always shorter than a page.
        var pages: [[AnyView]] = []
        var current: [AnyView] = []
        var currentHeight: CGFloat = 0
        for block in blocks {
            let h = measuredHeight(block, width: contentWidth) + gap
            if !current.isEmpty, currentHeight + h > available {
                pages.append(current)
                current = []
                currentHeight = 0
            }
            current.append(block)
            currentHeight += h
        }
        if !current.isEmpty { pages.append(current) }
        if pages.isEmpty { pages = [[]] }

        // Overwrite any prior export at this URL (absence == success).
        try? FileManager.default.removeItem(at: url)

        var box = CGRect(origin: .zero, size: pageSize)
        guard
            let consumer = CGDataConsumer(url: url as CFURL),
            let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return false }

        let total = pages.count
        for (index, pageBlocks) in pages.enumerated() {
            let page = ReportPage(
                pageSize: pageSize, margin: margin, gap: gap,
                masthead: masthead, subhead: subhead,
                footer: footer(index + 1, total), blocks: pageBlocks
            )
            let renderer = ImageRenderer(content: page)
            renderer.proposedSize = ProposedViewSize(pageSize)
            renderer.render { _, draw in
                context.beginPDFPage(nil)
                draw(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        return true
    }

    /// Natural height of a view at a fixed content width (point height at scale 1).
    private static func measuredHeight(_ view: AnyView, width: CGFloat) -> CGFloat {
        let renderer = ImageRenderer(
            content: view.frame(width: width, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        )
        renderer.scale = 1
        return renderer.cgImage.map { CGFloat($0.height) } ?? 0
    }
}

/// One physical page: masthead at top, body blocks, footer pinned to the bottom.
/// White background and exact paper frame for print.
private struct ReportPage: View {
    let pageSize: CGSize
    let margin: CGFloat
    let gap: CGFloat
    let masthead: AnyView
    var subhead: AnyView?
    let footer: AnyView
    let blocks: [AnyView]

    var body: some View {
        VStack(spacing: gap) {
            masthead
            if let subhead { subhead }
            VStack(spacing: gap) {
                ForEach(blocks.indices, id: \.self) { blocks[$0] }
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(margin)
        .frame(width: pageSize.width, height: pageSize.height, alignment: .top)
        .background(Color.white)
        .environment(\.colorScheme, .light)   // reports are always light/print
    }
}

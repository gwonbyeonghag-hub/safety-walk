import SwiftUI

/// Minimal finger-drawn signature capture. Strokes are collected in the pad's own
/// coordinate space and rendered to PNG `Data` (white background for report legibility)
/// on each stroke end. Optional — leaving it blank keeps the bound `Data?` nil.
///
/// Shared by `ParticipantEditorView`(위험성평가) and `BriefingParticipantEditorView`(TBM) —
/// extracted from the former so both participant editors draw the exact same pad
/// (WO LEGAL-TBM-2 §1 "기존 UI 선례 재사용").
struct SignaturePad: View {
    @Binding var data: Data?

    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []
    @State private var padSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                canvas(strokes: strokes, current: current, color: .primary)
                if strokes.isEmpty && current.isEmpty {
                    Text(LocalizationKey.raSignatureSign.localized)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 160)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: PadSizeKey.self, value: proxy.size)
                }
            }
            .onPreferenceChange(PadSizeKey.self) { padSize = $0 }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { current.append($0.location) }
                    .onEnded { _ in
                        if !current.isEmpty { strokes.append(current); current = [] }
                        render()
                    }
            )
            // Without `.accessibilityElement(children: .ignore)` the accessibility tree
            // collapses this ZStack into its child placeholder Text (a StaticText whose
            // frame doesn't match the drawable/gesture area) instead of exposing the ZStack
            // itself — a coordinate-based XCUITest press-drag on "signature_pad" then lands
            // on the wrong hit target and never reaches the DragGesture. Treating the pad as
            // one opaque element (with its own label) fixes both the identifier target and
            // VoiceOver, which otherwise gets no description of a purely gestural control.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(LocalizationKey.raSignatureSign.localized))
            .accessibilityIdentifier("signature_pad")

            if !strokes.isEmpty {
                Button(role: .destructive) {
                    strokes = []; current = []; data = nil
                } label: {
                    Label(LocalizationKey.raSignatureClear.localized, systemImage: "trash")
                        .font(.caption)
                }
            }
        }
    }

    /// The stroke drawing, reused for both the on-screen pad and the off-screen render.
    private func canvas(strokes: [[CGPoint]], current: [CGPoint], color: Color) -> some View {
        Canvas { ctx, _ in
            var path = Path()
            for stroke in strokes { add(stroke, to: &path) }
            add(current, to: &path)
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }

    private func add(_ stroke: [CGPoint], to path: inout Path) {
        guard let first = stroke.first else { return }
        if stroke.count == 1 {
            // A tap: draw a short dot so single points are visible.
            path.addEllipse(in: CGRect(x: first.x - 1.25, y: first.y - 1.25, width: 2.5, height: 2.5))
            return
        }
        path.move(to: first)
        for p in stroke.dropFirst() { path.addLine(to: p) }
    }

    @MainActor private func render() {
        guard padSize.width > 0, padSize.height > 0 else { data = nil; return }
        let content = ZStack {
            Color.white
            canvas(strokes: strokes, current: [], color: .black)
        }
        .frame(width: padSize.width, height: padSize.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        data = renderer.uiImage?.pngData()
    }
}

private struct PadSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

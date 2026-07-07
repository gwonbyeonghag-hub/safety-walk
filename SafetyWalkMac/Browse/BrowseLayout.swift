import SwiftUI
import SafetyWalkCore

/// A native macOS list + read-only detail pane used by every browse section. Selecting a
/// row on the left shows its detail on the right; the first row is selected on appear.
struct BrowseLayout<Item: Identifiable, Row: View, Detail: View>: View where Item.ID: Hashable {
    let items: [Item]
    @ViewBuilder var row: (Item) -> Row
    @ViewBuilder var detail: (Item) -> Detail

    @State private var selection: Item.ID?

    var body: some View {
        HStack(spacing: 0) {
            List(items, selection: $selection) { item in
                row(item).tag(item.id)
            }
            .listStyle(.inset)
            .tint(Color.macAccent)
            .frame(width: 300)

            Divider()

            Group {
                if let id = selection, let item = items.first(where: { $0.id == id }) {
                    ScrollView { detail(item).padding(MacTheme.s6) }
                } else {
                    ContentUnavailableView(LocalizationKey.macSelectItem.localized,
                                           systemImage: "sidebar.left")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.macBg)
        }
        .onAppear { if selection == nil { selection = items.first?.id } }
    }
}

/// Shared section header for the read-only detail panes (mockup `.h1`/`.sub`).
struct DetailHeader: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.macInk)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.macMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A labeled key/value row for detail panes.
struct DetailField: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.macMuted)
                .frame(width: 92, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 13))
                .foregroundStyle(Color.macInk)
            Spacer(minLength: 0)
        }
    }
}

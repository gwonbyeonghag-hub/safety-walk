import SwiftUI
import SafetyWalkCore
import SwiftData
import PhotosUI

struct ChecklistView: View {

    @Bindable var inspection: Inspection
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showSummary = false

    // Read items via the @Relationship on Inspection.
    // @Query with #Predicate inside a depth-2 pushed destination froze the app on iOS 17/18;
    // the relationship-backed source is the proven-safe pattern.
    private var items: [ChecklistItem] {
        (inspection.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Derived

    private var groupedItems: [(category: String, items: [ChecklistItem])] {
        var order: [String] = []
        var dict: [String: [ChecklistItem]] = [:]
        for item in items {
            if dict[item.category] == nil {
                order.append(item.category)
                dict[item.category] = []
            }
            dict[item.category]!.append(item)
        }
        return order.map { (category: $0, items: dict[$0]!) }
    }

    private var checkedCount: Int { items.filter { $0.result != .unchecked }.count }
    private var failedCount: Int  { items.filter { $0.result == .fail }.count }
    private var allChecked: Bool  { !items.isEmpty && checkedCount == items.count }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(groupedItems, id: \.category) { group in
                    // Closure-based NavigationLink is safe here because the destination
                    // owns no @Query (items pass through as `let [ChecklistItem]`).
                    // Co-locating one `.navigationDestination(isPresented:)` with a
                    // type-based `.navigationDestination(for:)` on the same pushed view
                    // caused back-navigation to land on the wrong screen on iOS 17/18.
                    NavigationLink {
                        ChecklistCategoryDetailView(
                            inspection: inspection,
                            categoryKey: group.category,
                            items: group.items
                        )
                    } label: {
                        CategoryRow(group: group)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .top, spacing: 0) { progressHeader }
        .safeAreaInset(edge: .bottom, spacing: 0) { completeButton }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSummary) {
            InspectionSummaryView(inspection: inspection)
        }
        .onChange(of: showSummary) { _, isShowing in
            if !isShowing && inspection.status == .completed {
                dismiss()
            }
        }
    }

    // MARK: - Progress header

    private var navigationTitle: String {
        if let area = inspection.areaName, !area.isEmpty {
            return "\(inspection.siteName) · \(area)"
        }
        return inspection.siteName
    }

    private var progressHeader: some View {
        HStack(spacing: 12) {
            Text(String(
                format: LocalizationKey.checklistProgress.localized,
                checkedCount, items.count
            ))
            .font(.subheadline.weight(.medium))

            Spacer()

            if failedCount > 0 {
                Text(String(
                    format: LocalizationKey.checklistFailedCount.localized,
                    failedCount
                ))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Complete button

    private var completeButton: some View {
        Button {
            inspection.status = .completed
            inspection.completedAt = Date()
            try? modelContext.save()
            showSummary = true
        } label: {
            Text(LocalizationKey.inspectionComplete.localized)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!allChecked || inspection.status == .completed)
        .padding()
    }
}

// MARK: - CategoryRow

private struct CategoryRow: View {

    let group: (category: String, items: [ChecklistItem])

    private var total: Int        { group.items.count }
    private var checkedCount: Int { group.items.filter { $0.result != .unchecked }.count }
    private var failedCount: Int  { group.items.filter { $0.result == .fail }.count }
    private var allChecked: Bool  { checkedCount == total && total > 0 }
    private var fraction: Double  { total > 0 ? Double(checkedCount) / Double(total) : 0 }

    private var progressColor: Color {
        if failedCount > 0 { return .orange }
        return checkedCount > 0 ? .green : Color(.systemGray4)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            statusIcon
                .font(.title3)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(L(group.category))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text("\(checkedCount) / \(total)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)

                    if failedCount > 0 {
                        Text(String(
                            format: LocalizationKey.checklistFailedCount.localized,
                            failedCount
                        ))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.red.opacity(0.1), in: Capsule())
                    }
                }

                progressBar
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var statusIcon: some View {
        if allChecked && failedCount == 0 {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if allChecked {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        } else if checkedCount > 0 {
            Image(systemName: "circle.bottomhalf.filled")
                .foregroundStyle(Color.accentColor)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(Color(.systemGray3))
        }
    }

    private var progressBar: some View {
        Capsule()
            .fill(Color(.systemGray5))
            .frame(height: 3)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(progressColor)
                    .frame(height: 3)
                    .scaleEffect(x: fraction, y: 1, anchor: .leading)
                    .opacity(fraction > 0 ? 1 : 0)
            }
    }
}

// MARK: - ChecklistItemRow
// internal (not private) so ChecklistCategoryDetailView can reuse it

struct ChecklistItemRow: View {

    @Bindable var item: ChecklistItem
    let inspection: Inspection

    @State private var pickerItem: PhotosPickerItem?
    @State private var thumbnail: UIImage?
    @State private var showHazardSheet = false

    // Photo error surfacing (5-3). Two separate flags so we never lose the
    // distinction between "couldn't read the picker result" and "disk save failed".
    @State private var showPhotoLoadFailed = false
    @State private var showPhotoSaveFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(item.title))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            resultButtons

            if item.result != .unchecked {
                noteField
                photoRow
                if item.result == .fail {
                    hazardRow
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear(perform: loadThumbnailIfNeeded)
        .task(id: pickerItem) {
            await saveSelectedPhoto()
        }
        .sheet(isPresented: $showHazardSheet) {
            HazardRegistrationView(inspection: inspection, checklistItem: item)
        }
        .alert(LocalizationKey.errorPhotoLoadFailed.localized,
               isPresented: $showPhotoLoadFailed) {
            Button(LocalizationKey.commonConfirm.localized) {}
        }
        .alert(LocalizationKey.errorPhotoSaveFailed.localized,
               isPresented: $showPhotoSaveFailed) {
            Button(LocalizationKey.commonConfirm.localized) {}
        }
    }

    // MARK: - Result buttons

    private var resultButtons: some View {
        HStack(spacing: 1) {
            resultButton(.pass)
            resultButton(.fail)
            resultButton(.notApplicable)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func resultButton(_ result: ChecklistItemResult) -> some View {
        let isSelected = item.result == result
        Button {
            item.result = isSelected ? .unchecked : result
        } label: {
            Text(label(for: result))
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isSelected ? .white : tint(for: result))
                .background(isSelected ? tint(for: result) : tint(for: result).opacity(0.08))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func label(for result: ChecklistItemResult) -> String {
        switch result {
        case .pass:          return LocalizationKey.checklistPass.localized
        case .fail:          return LocalizationKey.checklistFail.localized
        case .notApplicable: return LocalizationKey.checklistNotApplicable.localized
        case .unchecked:     return ""
        }
    }

    private func tint(for result: ChecklistItemResult) -> Color {
        switch result {
        case .pass:          return .green
        case .fail:          return .red
        case .notApplicable: return Color(.systemGray)
        case .unchecked:     return Color(.systemGray)
        }
    }

    // MARK: - Note field

    private var noteField: some View {
        TextField(
            LocalizationKey.checklistAddNote.localized,
            text: Binding(
                get: { item.note ?? "" },
                set: { item.note = $0.isEmpty ? nil : $0 }
            ),
            axis: .vertical
        )
        .font(.caption)
        .textFieldStyle(.roundedBorder)
        .lineLimit(1...3)
    }

    // MARK: - Photo row

    private var photoRow: some View {
        HStack(spacing: 8) {
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
                    .accessibilityHidden(true)
            }

            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    item.photoData == nil
                        ? LocalizationKey.checklistAttachPhoto.localized
                        : LocalizationKey.checklistReplacePhoto.localized,
                    systemImage: item.photoData == nil ? "camera" : "arrow.triangle.2.circlepath"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(item.photoData == nil ? Color.secondary : Color.accentColor)
        }
    }

    // MARK: - Hazard row

    private var hazardRow: some View {
        Group {
            if item.linkedHazardId != nil {
                Label(LocalizationKey.checklistHazardLinked.localized,
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Button { showHazardSheet = true } label: {
                    Label(LocalizationKey.checklistAddHazard.localized,
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Photo helpers

    private func loadThumbnailIfNeeded() {
        guard thumbnail == nil, let data = item.photoData else { return }
        thumbnail = UIImage(data: data)
    }

    private func saveSelectedPhoto() async {
        guard let selected = pickerItem else { return }

        // Load the picker result into a UIImage. Any failure surfaces as a load error.
        let loadedData: Data?
        do {
            loadedData = try await selected.loadTransferable(type: Data.self)
        } catch {
            pickerItem = nil
            showPhotoLoadFailed = true
            return
        }
        guard let raw = loadedData, let image = UIImage(data: raw) else {
            pickerItem = nil
            showPhotoLoadFailed = true
            return
        }

        let newData: Data
        do {
            newData = try PhotoStorageService().data(from: image)
        } catch {
            pickerItem = nil
            showPhotoSaveFailed = true
            return
        }

        item.photoData = newData
        thumbnail = UIImage(data: newData)
        pickerItem = nil
    }
}

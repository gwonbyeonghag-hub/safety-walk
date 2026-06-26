import SwiftUI
import SafetyWalkCore
import SwiftData

struct AreaSelectionView: View {

    @Binding var isDone: Bool
    @Binding var path: [FlowStep]
    @Environment(StartInspectionViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext

    private let siteId: UUID
    @Query private var areas: [Area]

    @State private var isAddingArea = false
    @State private var newAreaName = ""

    init(isDone: Binding<Bool>, siteId: UUID, path: Binding<[FlowStep]>) {
        _isDone = isDone
        _path = path
        self.siteId = siteId
        _areas = Query(
            filter: #Predicate<Area> { area in area.siteId == siteId },
            sort: [SortDescriptor(\Area.name)]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                // "No specific area" option
                AreaOptionRow(
                    label: LocalizationKey.inspectionNoArea.localized,
                    systemImage: "minus.circle",
                    isSelected: viewModel.skipArea
                ) {
                    viewModel.skipArea = true
                    viewModel.selectedArea = nil
                    viewModel.areaFreeText = ""
                }

                // Saved areas for this site
                ForEach(areas) { area in
                    AreaOptionRow(
                        label: area.name,
                        systemImage: "mappin",
                        isSelected: !viewModel.skipArea && viewModel.selectedArea?.id == area.id
                    ) {
                        viewModel.skipArea = false
                        viewModel.selectedArea = area
                        viewModel.areaFreeText = ""
                    }
                }
            }
            .listStyle(.insetGrouped)

            addAreaSection
            nextButton
        }
        .navigationTitle(LocalizationKey.inspectionSelectArea.localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(LocalizationKey.commonCancel.localized) { isDone = true }
            }
        }
        .onAppear {
            // Default to "No specific area" if nothing selected yet
            if viewModel.selectedArea == nil && !viewModel.skipArea &&
               viewModel.areaFreeText.isEmpty {
                viewModel.skipArea = true
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var addAreaSection: some View {
        VStack(spacing: 8) {
            if isAddingArea {
                VStack(spacing: 8) {
                    TextField(
                        LocalizationKey.areaNamePlaceholder.localized,
                        text: $newAreaName
                    )
                    .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        Button(LocalizationKey.commonCancel.localized) {
                            isAddingArea = false
                            newAreaName = ""
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Button(LocalizationKey.commonSave.localized) {
                            saveArea()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(newAreaName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            } else {
                // Free-text field for one-off area names (not saved to database)
                TextField(
                    LocalizationKey.inspectionEnterAreaFree.localized,
                    text: Binding(
                        get: { viewModel.areaFreeText },
                        set: { text in
                            viewModel.areaFreeText = text
                            if !text.isEmpty {
                                viewModel.skipArea = false
                                viewModel.selectedArea = nil
                            }
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.top, 8)

                Button {
                    isAddingArea = true
                } label: {
                    Label(
                        LocalizationKey.inspectionAddNewArea.localized,
                        systemImage: "plus.circle"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
    }

    private var nextButton: some View {
        Button {
            path.append(.template)
        } label: {
            Text(LocalizationKey.commonNext.localized)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }

    // MARK: - Actions

    private func saveArea() {
        let name = newAreaName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let area = Area(name: name, siteId: siteId)
        modelContext.insert(area)
        viewModel.skipArea = false
        viewModel.selectedArea = area
        viewModel.areaFreeText = ""
        isAddingArea = false
        newAreaName = ""
    }
}

// MARK: - AreaOptionRow

private struct AreaOptionRow: View {
    let label: String
    let systemImage: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

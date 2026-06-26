import SwiftUI
import SafetyWalkCore
import SwiftData

struct SiteSelectionView: View {

    @Binding var isDone: Bool
    @Binding var path: [FlowStep]
    @Environment(StartInspectionViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Site.name) private var sites: [Site]

    @State private var isAddingSite = false
    @State private var newSiteName = ""
    @State private var newSiteAddress = ""

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(sites) { site in
                    SiteRowView(
                        site: site,
                        isSelected: viewModel.selectedSite?.id == site.id
                    ) {
                        viewModel.selectedSite = site
                    }
                }

                if sites.isEmpty {
                    Text(LocalizationKey.inspectionNoSitesYet.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)

            addSiteSection
            nextButton
        }
        .navigationTitle(LocalizationKey.inspectionSelectSite.localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(LocalizationKey.commonCancel.localized) { isDone = true }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var addSiteSection: some View {
        VStack(spacing: 8) {
            if isAddingSite {
                VStack(spacing: 8) {
                    TextField(
                        LocalizationKey.siteNamePlaceholder.localized,
                        text: $newSiteName
                    )
                    .textFieldStyle(.roundedBorder)

                    TextField(
                        LocalizationKey.siteAddressPlaceholder.localized,
                        text: $newSiteAddress
                    )
                    .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        Button(LocalizationKey.commonCancel.localized) {
                            isAddingSite = false
                            newSiteName = ""
                            newSiteAddress = ""
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Button(LocalizationKey.commonSave.localized) {
                            saveSite()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(newSiteName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            } else {
                Button {
                    isAddingSite = true
                } label: {
                    Label(
                        LocalizationKey.inspectionAddNewSite.localized,
                        systemImage: "plus.circle"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }

    private var nextButton: some View {
        Button {
            if let siteId = viewModel.selectedSite?.id {
                path.append(.area(siteId))
            }
        } label: {
            Text(LocalizationKey.commonNext.localized)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canProceedFromSite)
        .padding()
    }

    // MARK: - Actions

    private func saveSite() {
        let name = newSiteName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let address = newSiteAddress.trimmingCharacters(in: .whitespaces)
        let site = Site(name: name, address: address.isEmpty ? nil : address)
        modelContext.insert(site)
        viewModel.selectedSite = site
        isAddingSite = false
        newSiteName = ""
        newSiteAddress = ""
    }
}

// MARK: - SiteRowView

private struct SiteRowView: View {
    let site: Site
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(site.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let address = site.address, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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

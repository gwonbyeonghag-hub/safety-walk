import SwiftUI
import SwiftData
import SafetyWalkCore

struct RiskAssessmentsBrowseView: View {
    @Query private var assessments: [RiskAssessment]

    private var sorted: [RiskAssessment] {
        assessments.sorted { ($0.assessedAt ?? $0.createdAt) > ($1.assessedAt ?? $1.createdAt) }
    }

    var body: some View {
        BrowseLayout(items: sorted) { ra in
            VStack(alignment: .leading, spacing: 2) {
                Text(ra.siteName.isEmpty ? ra.method.localizedLabel : ra.siteName).font(.body).lineLimit(1)
                HStack(spacing: 6) {
                    Text(ra.method.localizedLabel)
                    Text("·")
                    Text((ra.assessedAt ?? ra.createdAt).formatted(date: .abbreviated, time: .omitted)).monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        } detail: { ra in
            detail(ra)
        }
        .navigationTitle(LocalizationKey.macSectionRiskAssessments.localized)
    }

    @ViewBuilder
    private func detail(_ ra: RiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailHeader(title: ra.siteName.isEmpty ? ra.method.localizedLabel : ra.siteName,
                         subtitle: "\(ra.kind.localizedLabel) · \(ra.method.localizedLabel)")

            MacCard {
                VStack(spacing: 6) {
                    DetailField(label: LocalizationKey.raAssessor.localized, value: ra.assessorName)
                    DetailField(label: LocalizationKey.raMethod.localized, value: ra.method.localizedLabel)
                    DetailField(label: LocalizationKey.raKind.localized, value: ra.kind.localizedLabel)
                    // WO LEGAL-3A: 저장된 업종 스냅샷 — 조회 전용(Mac 은 생성·편집하지 않는다).
                    DetailField(label: LocalizationKey.raIndustry.localized,
                                value: ra.industryDisplayText)
                    DetailField(label: LocalizationKey.commonDone.localized,
                                value: (ra.assessedAt ?? ra.createdAt).formatted(date: .abbreviated, time: .shortened))
                }
            }

            // WO LEGAL-3B §E: US 관할 평가에만 Federal/State Plan 경고를 보인다.
            if JurisdictionPolicy.showsFederalNotice(ra.jurisdictionSnapshot) {
                USFederalNoticeInline()
            }

            MacCard(title: LocalizationKey.macSectionRiskAssessments.localized, systemImage: "tablecells") {
                let items = (ra.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
                VStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(idx + 1)").font(.callout.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(Color.brandNavy).frame(width: 22, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.taskDescription).font(.callout.weight(.medium))
                                Text(item.hazardDescription).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 2) {
                                if let level = item.riskLevel {
                                    RiskChip(level: level)
                                } else {
                                    Text(LocalizationKey.raRiskUnassessed.localized)
                                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                }
                                if ra.method.usesFrequencySeverity, let l = item.likelihood, let s = item.severity {
                                    Text("\(l)×\(s)=\(l * s)").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                                }
                            }
                        }
                        if item.id != items.last?.id { Divider() }
                    }
                }
            }

            // 공유 이력 — 조회 전용(WO LEGAL-2d). 생성·확정은 iOS 현장 도구가 담당한다.
            MacSharingHistoryCard(assessment: ra)

            ReportDisclaimerInline()
        }
    }
}

/// Inline disclaimer echo for on-screen detail (the printed report carries the full legal
/// disclaimer; on screen we surface the same "records, not a legal determination" note).
struct ReportDisclaimerInline: View {
    var body: some View {
        Text(LocalizationKey.disclaimerText.localized)
            .font(.caption)
            .foregroundStyle(Color.macMuted)
            .padding(MacTheme.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.macSurface2, in: RoundedRectangle(cornerRadius: MacTheme.smallRadius))
            .overlay(RoundedRectangle(cornerRadius: MacTheme.smallRadius).strokeBorder(Color.macBorder, lineWidth: 1))
    }
}

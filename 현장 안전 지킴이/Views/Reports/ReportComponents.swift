import SwiftUI
import SafetyWalkCore

// Shared print-design components for reports (DESIGN_DIRECTION §7): navy masthead,
// SOLID risk color bands (not the on-screen liquid-glass), monospaced numbers, white
// background, and the legally-required disclaimer on every report. Fixed point sizes
// (not Dynamic Type) for precise print layout. Cross-platform (no UIKit).

extension Color {
    /// Fixed deep navy for print mastheads/rules (reports are always light/white).
    static let reportNavy = Color(red: 0.10, green: 0.22, blue: 0.42)
}

/// Navy masthead repeated at the top of every report page.
struct ReportMasthead: View {
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer(minLength: 8)
            Text("SafetyWalk")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.reportNavy)
    }
}

/// Footer with a thin navy rule and a monospaced page n/k, repeated on every page.
struct ReportFooter: View {
    let page: Int
    let total: Int

    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(Color.reportNavy.opacity(0.3))
                .frame(height: 0.5)
            HStack {
                Text("SafetyWalk")
                    .font(.system(size: 8))
                    .foregroundStyle(.black.opacity(0.45))
                Spacer()
                Text("\(page) / \(total)")
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
    }
}

/// SOLID risk color band for print (vs the on-screen translucent RiskChip).
struct ReportRiskBand: View {
    let level: RiskLevel
    var body: some View {
        Text(level.localizedLabel)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(level.uiColor, in: Capsule())
            .fixedSize()
    }
}

/// Legally-required disclaimer block — present on every report (the app records, it
/// does not determine legal compliance). Reuses the app's disclaimer strings.
struct ReportDisclaimer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizationKey.disclaimerTitle.localized)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.reportNavy)
            Text(LocalizationKey.disclaimerText.localized)
                .font(.system(size: 8))
                .foregroundStyle(.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.reportNavy.opacity(0.3), lineWidth: 0.5)
        )
    }
}

/// Federal OSHA baseline + State Plan disclaimer (WO LEGAL-3B §E) — printed on every PDF tied to
/// a US Federal checklist template or a US-jurisdiction risk assessment/JHA. Mirrors
/// `ReportDisclaimer`'s look so it reads as part of the same legal-notice family, not a separate
/// design. `USFederalNoticeInline` below renders the identical string on-screen; both consumers
/// read the same shared `LocalizationKey.usFederalNoticeText` so no site holds its own copy.
struct USFederalNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizationKey.usFederalNoticeTitle.localized)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.reportNavy)
            Text(LocalizationKey.usFederalNoticeText.localized)
                .font(.system(size: 8))
                .foregroundStyle(.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.reportNavy.opacity(0.3), lineWidth: 0.5)
        )
    }
}

/// On-screen echo of `USFederalNotice` (Dynamic Type, not fixed pt) — reused across the iOS
/// authoring/detail screens and the macOS browse screen (this file is already cross-included to
/// both targets), so no screen writes its own copy of the notice text (WO LEGAL-3B §E).
struct USFederalNoticeInline: View {
    var body: some View {
        Text(LocalizationKey.usFederalNoticeText.localized)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(6)
            .background(Color.reportNavy.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
    }
}

/// Key/value header grid used by report headers (site, assessor, date, …).
struct ReportInfoGrid: View {
    let pairs: [(String, String)]
    var columns = 2

    var body: some View {
        let rows = stride(from: 0, to: pairs.count, by: columns).map { start in
            Array(pairs[start..<min(start + columns, pairs.count)])
        }
        VStack(spacing: 4) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 12) {
                    ForEach(rows[r].indices, id: \.self) { c in
                        let pair = rows[r][c]
                        HStack(spacing: 5) {
                            Text(pair.0)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.reportNavy)
                            Text(pair.1)
                                .font(.system(size: 9))
                                .foregroundStyle(.black)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if rows[r].count < columns {
                        ForEach(0..<(columns - rows[r].count), id: \.self) { _ in
                            Spacer().frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.reportNavy.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
    }
}

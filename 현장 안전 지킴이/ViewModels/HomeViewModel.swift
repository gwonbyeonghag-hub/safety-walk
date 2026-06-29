import Foundation
import SafetyWalkCore
import SwiftUI
import Observation

@Observable
final class HomeViewModel {

    // MARK: - Date formatting

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    func formattedDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return Self.shortDateFormatter.string(from: date)
        }
        return Self.shortDateFormatter.string(from: date)
    }

    // MARK: - Inspection result counts (derived from snapshot items)

    func passCount(for inspection: Inspection) -> Int {
        inspection.items.filter { $0.result == .pass }.count
    }

    func failCount(for inspection: Inspection) -> Int {
        inspection.items.filter { $0.result == .fail }.count
    }

    // MARK: - Status display

    func statusLabel(for inspection: Inspection) -> String {
        switch inspection.status {
        case .inProgress: return LocalizationKey.inspectionStatusInProgress.localized
        case .completed:  return LocalizationKey.inspectionStatusCompleted.localized
        }
    }

    func statusColor(for inspection: Inspection) -> Color {
        inspection.status == .completed ? .green : .blue
    }
}

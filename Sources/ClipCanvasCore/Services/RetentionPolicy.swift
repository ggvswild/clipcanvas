import Foundation

public enum RetentionPeriod: String, Codable, CaseIterable, Sendable {
    case day
    case week
    case month
    case year
    case forever

    public func cutoff(
        relativeTo reference: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        switch self {
        case .day:
            return calendar.date(byAdding: .day, value: -1, to: reference)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: reference)
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: reference)
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: reference)
        case .forever:
            return nil
        }
    }
}

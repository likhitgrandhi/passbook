
import Foundation

enum Granularity: String, CaseIterable {
    case day, week, month
}

struct DateRange {
    let start: Date
    let end: Date
}

func dateRange(for granularity: Granularity, anchor: Date) -> DateRange {
    let cal = Calendar.current
    switch granularity {
    case .day:
        return DateRange(
            start: cal.startOfDay(for: anchor),
            end: cal.date(bySettingHour: 23, minute: 59, second: 59, of: anchor) ?? anchor
        )
    case .week:
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)
        let start = cal.date(from: comps) ?? anchor
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? anchor
        return DateRange(
            start: start,
            end: cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        )
    case .month:
        let comps = cal.dateComponents([.year, .month], from: anchor)
        let start = cal.date(from: comps) ?? anchor
        guard let range = cal.range(of: .day, in: .month, for: anchor) else {
            return DateRange(start: anchor, end: anchor)
        }
        let end = cal.date(byAdding: .day, value: range.count - 1, to: start) ?? anchor
        return DateRange(
            start: start,
            end: cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        )
    }
}

func shiftAnchor(_ anchor: Date, granularity: Granularity, delta: Int) -> Date {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    let candidate: Date
    switch granularity {
    case .day:   candidate = cal.date(byAdding: .day, value: delta, to: anchor) ?? anchor
    case .week:  candidate = cal.date(byAdding: .weekOfYear, value: delta, to: anchor) ?? anchor
    case .month: candidate = cal.date(byAdding: .month, value: delta, to: anchor) ?? anchor
    }
    // Never allow navigating into the future
    return min(candidate, today)
}

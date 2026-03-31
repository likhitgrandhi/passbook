
import Foundation
import Observation
import SwiftData

private extension Double {
    /// Returns nil if zero (so UserDefaults unset values don't override defaults).
    var nonZero: Double? { self == 0 ? nil : self }
}

/// Holds only non-persisted UI state (daily budget) and provides
/// pure computation helpers that operate on a transaction array passed in.
/// The actual transactions come from @Query in each view — this keeps
/// the AppIntent's SwiftData writes automatically visible everywhere.
@Observable
@MainActor
final class TransactionStore {
    var dailyBudget: Double = UserDefaults.standard.double(forKey: "dailyBudget").nonZero ?? 1500 {
        didSet { UserDefaults.standard.set(dailyBudget, forKey: "dailyBudget") }
    }

    /// All debit transactions in range — shown in the list regardless of exclusion
    func filteredTransactions(_ transactions: [Transaction], in range: DateRange) -> [Transaction] {
        transactions.filter {
            $0.type == "debit" &&
            $0.date >= range.start &&
            $0.date <= range.end
        }
    }

    /// Only non-excluded debits — used for totals and chart bars
    private func billableTransactions(_ transactions: [Transaction], in range: DateRange) -> [Transaction] {
        filteredTransactions(transactions, in: range).filter { !$0.excludedFromCalc }
    }

    func totalSpent(_ transactions: [Transaction], in range: DateRange) -> Double {
        billableTransactions(transactions, in: range).reduce(0) { $0 + $1.amount }
    }

    func chartBars(from transactions: [Transaction], granularity: Granularity, anchor: Date) -> [ChartBar] {
        let cal = Calendar.current
        switch granularity {
        case .day:
            return (0..<7).reversed().map { offset -> ChartBar in
                let day = cal.date(byAdding: .day, value: -offset, to: anchor) ?? anchor
                let range = dateRange(for: .day, anchor: day)
                return ChartBar(
                    id: day.formatted(.iso8601.year().month().day()),
                    label: day.formatted(.dateTime.weekday(.abbreviated)),
                    amount: totalSpent(transactions, in: range),
                    periodStart: range.start,
                    periodEnd: range.end
                )
            }
        case .week:
            return (0..<7).reversed().map { offset -> ChartBar in
                let weekAnchor = cal.date(byAdding: .weekOfYear, value: -offset, to: anchor) ?? anchor
                let range = dateRange(for: .week, anchor: weekAnchor)
                return ChartBar(
                    id: range.start.formatted(.iso8601.year().month().day()),
                    label: range.start.formatted(.dateTime.day().month(.abbreviated)),
                    amount: totalSpent(transactions, in: range),
                    periodStart: range.start,
                    periodEnd: range.end
                )
            }
        case .month:
            return (0..<12).reversed().map { offset -> ChartBar in
                let monthAnchor = cal.date(byAdding: .month, value: -offset, to: anchor) ?? anchor
                let range = dateRange(for: .month, anchor: monthAnchor)
                return ChartBar(
                    id: range.start.formatted(.iso8601.year().month().day()),
                    label: monthAnchor.formatted(.dateTime.month(.abbreviated)),
                    amount: totalSpent(transactions, in: range),
                    periodStart: range.start,
                    periodEnd: range.end
                )
            }
        }
    }
}

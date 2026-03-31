import Foundation
import SwiftData

@Model
final class MonthlyBudget {
    var id: String
    var month: String           // "yyyy-MM"
    var income: Double
    var fixedLiabilities: Double  // EMIs, loans, rent, etc.
    var spendBudget: Double       // discretionary spend target
    var createdAt: Date

    var disposableIncome: Double { income - fixedLiabilities }
    var savings: Double { disposableIncome - spendBudget }
    var yearlySavings: Double { savings * 12 }

    init(month: String, income: Double, fixedLiabilities: Double, spendBudget: Double) {
        self.id = "mb-\(month)"
        self.month = month
        self.income = income
        self.fixedLiabilities = fixedLiabilities
        self.spendBudget = spendBudget
        self.createdAt = .now
    }

    // "yyyy-MM" → "March 2025"
    var displayTitle: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        guard let date = df.date(from: month) else { return month }
        df.dateFormat = "MMMM yyyy"
        return df.string(from: date)
    }
}

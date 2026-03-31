
import ActivityKit
import Foundation

struct TransactionActivityAttributes: ActivityAttributes {
    // Static data set at activity start — doesn't change
    let merchant: String
    let categoryEmoji: String

    // Dynamic state — can be updated while activity is live
    struct ContentState: Codable, Hashable {
        let transactionAmount: Double   // e.g. 1140.0
        let budgetSpentFraction: Double // 0.0–1.0 for progress bar
        let dailyBudgetRemaining: Double // today's remaining budget in ₹
        let isOverBudget: Bool
    }
}

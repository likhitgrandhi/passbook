
import Foundation
import SwiftData

@Model
final class PassbookSubscription {
    var id: String
    var merchant: String
    var amount: Double
    var frequency: String      // "weekly", "monthly", "annual"
    var nextRenewal: Date
    var isActive: Bool
    var isManual: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString, merchant: String, amount: Double,
         frequency: String, nextRenewal: Date, isActive: Bool = true, isManual: Bool = false) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.frequency = frequency
        self.nextRenewal = nextRenewal
        self.isActive = isActive
        self.isManual = isManual
        self.createdAt = .now
    }
}

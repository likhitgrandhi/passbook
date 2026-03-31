
import Foundation
import SwiftData

@Model
final class Budget {
    var id: String
    var category: String
    var amount: Double
    var month: String          // "yyyy-MM"
    var applyForward: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString, category: String, amount: Double,
         month: String, applyForward: Bool = true) {
        self.id = id
        self.category = category
        self.amount = amount
        self.month = month
        self.applyForward = applyForward
        self.createdAt = .now
    }
}

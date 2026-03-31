
import Foundation
import SwiftData

@Model
final class Transaction {
    var id: String
    var date: Date
    var amount: Double
    var type: String          // "debit" or "credit"
    var merchant: String
    var merchantRaw: String
    var category: String
    var subcategory: String?
    var account: String
    var bank: String
    var notes: String
    var isRecurring: Bool
    var excludedFromCalc: Bool
    var source: String        // "sms", "manual", "seed"
    var rawText: String
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, date: Date, amount: Double, type: String,
         merchant: String, merchantRaw: String = "", category: String,
         subcategory: String? = nil, account: String = "", bank: String = "",
         notes: String = "", isRecurring: Bool = false, excludedFromCalc: Bool = false,
         source: String = "manual", rawText: String = "") {
        self.id = id
        self.date = date
        self.amount = amount
        self.type = type
        self.merchant = merchant
        self.merchantRaw = merchantRaw
        self.category = category
        self.subcategory = subcategory
        self.account = account
        self.bank = bank
        self.notes = notes
        self.isRecurring = isRecurring
        self.excludedFromCalc = excludedFromCalc
        self.source = source
        self.rawText = rawText
        self.createdAt = .now
        self.updatedAt = .now
    }
}

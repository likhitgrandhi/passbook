import Foundation
import SwiftData

@Model
final class SMSLog {
    var id: String
    var rawText: String
    var receivedAt: Date
    var status: String       // "parsed", "rejected_otp", "rejected_future", "rejected_not_bank", "rejected_no_amount", "duplicate"
    var rejectionReason: String
    var parsedMerchant: String
    var parsedAmount: Double
    var createdAt: Date

    init(
        rawText: String,
        receivedAt: Date,
        status: String,
        rejectionReason: String = "",
        parsedMerchant: String = "",
        parsedAmount: Double = 0
    ) {
        self.id = UUID().uuidString
        self.rawText = rawText
        self.receivedAt = receivedAt
        self.status = status
        self.rejectionReason = rejectionReason
        self.parsedMerchant = parsedMerchant
        self.parsedAmount = parsedAmount
        self.createdAt = .now
    }
}


import ActivityKit
import AppIntents
import Foundation
import SwiftData
import UserNotifications

struct AddTransactionIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Bank Transaction"
    static var description = IntentDescription("Parses a bank SMS and saves the transaction to Passbook.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Message")
    var messageText: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log bank SMS \(\.$messageText)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // ── Early rejection: OTP ─────────────────────────────────────
        let otpPattern = "OTP|one.?time.?pass|password|PIN|CVV|verification code|login code|security code"
        if messageText.range(of: otpPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            await logSMS(status: "rejected_otp", reason: "OTP / security message")
            return .result(dialog: "Skipped: OTP message.")
        }

        // ── Parse ────────────────────────────────────────────────────
        guard let parsed = parseSMS(text: messageText, sender: "", receivedAt: Date.now) else {
            await logSMS(status: "rejected_parse", reason: "Could not parse amount, type, or failed bank/future filters")
            return .result(dialog: "Could not parse transaction.")
        }

        let category = categorize(merchant: parsed.merchant)

        // ── Improved hash: includes merchant + account ───────────────
        var hash: UInt64 = 5381
        let hashInput = "\(parsed.amount)|\(parsed.date.timeIntervalSince1970.rounded())|\(parsed.type)|\(parsed.merchant)|\(parsed.account)"
        for byte in hashInput.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        let deterministicID = "tx-\(String(hash, radix: 16))"

        // ── Save ─────────────────────────────────────────────────────
        let (saveResult, todaySpent) = try await MainActor.run { () throws -> (Bool, Double) in
            let context = ModelContext(SharedModelContainer.shared)
            let idToCheck = deterministicID
            let existing = try context.fetch(
                FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == idToCheck })
            )
            guard existing.isEmpty else {
                // Log as duplicate
                context.insert(SMSLog(
                    rawText: messageText,
                    receivedAt: Date.now,
                    status: "duplicate",
                    rejectionReason: "Transaction ID already exists: \(deterministicID)",
                    parsedMerchant: parsed.merchant,
                    parsedAmount: parsed.amount
                ))
                try? context.save()
                return (false, 0)
            }

            context.insert(Transaction(
                id: deterministicID,
                date: parsed.date,
                amount: parsed.amount,
                type: parsed.type,
                merchant: parsed.merchant,
                merchantRaw: parsed.merchant,
                category: category,
                account: parsed.account,
                bank: parsed.bank,
                source: "sms",
                rawText: messageText
            ))

            // Log as successfully parsed
            context.insert(SMSLog(
                rawText: messageText,
                receivedAt: Date.now,
                status: "parsed",
                parsedMerchant: parsed.merchant,
                parsedAmount: parsed.amount
            ))

            try context.save()

            // Compute today's total spend (including this transaction)
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: Date.now)
            let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? Date.now
            let todayDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay && $0.type == "debit" && !$0.excludedFromCalc }
            )
            let todayTx = try context.fetch(todayDescriptor)
            let todayTotal = todayTx.reduce(0) { $0 + $1.amount }
            return (true, todayTotal)
        }

        if saveResult {
            let stored = UserDefaults.standard.double(forKey: "dailyBudget")
            let dailyBudget = stored > 0 ? stored : 1500
            let remaining = max(0, dailyBudget - todaySpent)
            let fraction = min(todaySpent / dailyBudget, 1.5)
            let isOver = todaySpent > dailyBudget

            await startLiveActivity(
                amount: parsed.amount,
                merchant: parsed.merchant,
                category: category,
                budgetSpentFraction: fraction,
                dailyBudgetRemaining: remaining,
                isOverBudget: isOver
            )
        }

        let amountStr = parsed.amount.formatted(.number.precision(.fractionLength(0...2)))
        return .result(dialog: saveResult
            ? "Saved: ₹\(amountStr) at \(parsed.merchant)"
            : "Already saved."
        )
    }

    @MainActor
    private func logSMS(status: String, reason: String) {
        let context = ModelContext(SharedModelContainer.shared)
        context.insert(SMSLog(
            rawText: messageText,
            receivedAt: Date.now,
            status: status,
            rejectionReason: reason
        ))
        try? context.save()
    }
}

// MARK: - Live Activity

private func startLiveActivity(
    amount: Double,
    merchant: String,
    category: String,
    budgetSpentFraction: Double,
    dailyBudgetRemaining: Double,
    isOverBudget: Bool
) async {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

    let attributes = TransactionActivityAttributes(
        merchant: merchant,
        categoryEmoji: emoji(for: category)
    )
    let state = TransactionActivityAttributes.ContentState(
        transactionAmount: amount,
        budgetSpentFraction: budgetSpentFraction,
        dailyBudgetRemaining: dailyBudgetRemaining,
        isOverBudget: isOverBudget
    )
    let content = ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(30))

    do {
        let activity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
        // Auto-dismiss after 20 seconds
        Task {
            try? await Task.sleep(for: .seconds(20))
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    } catch {
        // Fall back to a plain notification if Live Activity fails
        await sendFallbackNotification(amount: amount, merchant: merchant)
    }
}

// MARK: - Fallback Notification

private func sendFallbackNotification(amount: Double, merchant: String) async {
    let center = UNUserNotificationCenter.current()
    let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    guard granted else { return }
    let content = UNMutableNotificationContent()
    content.title = "₹\(Int(amount)) logged"
    content.body = merchant
    content.sound = .default
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    try? await center.add(request)
}

// MARK: - Helpers

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

private func emoji(for category: String) -> String {
    switch category {
    case "Food & Dining":       return "🍔"
    case "Auto & Transport":    return "🚗"
    case "Shopping":            return "🛍️"
    case "Subscriptions":       return "📱"
    case "Health & Wellness":   return "💊"
    case "Entertainment":       return "🎬"
    case "Housing":             return "🏠"
    case "Education":           return "📚"
    case "Investments":         return "📈"
    case "Travel & Vacation":   return "✈️"
    case "Transfers":           return "💸"
    default:                    return "💳"
    }
}

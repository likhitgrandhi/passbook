import Foundation

struct ParsedSMSTransaction {
    let amount: Double
    let type: String          // "debit" or "credit"
    let merchant: String
    let bank: String
    let account: String
    let date: Date
}

// MARK: - OTP / Security Filter

nonisolated(unsafe) private let otpPattern = "OTP|one.?time.?pass|password|PIN|CVV|verification code|login code|security code"

nonisolated private func isOTPMessage(_ text: String) -> Bool {
    text.range(of: otpPattern, options: [.regularExpression, .caseInsensitive]) != nil
}

// MARK: - Future / Scheduled Event Filter
// Rejects messages about upcoming debits, mandates, due dates, and reminders.
// These describe future events, not completed transactions.

nonisolated(unsafe) private let futureTensePattern = [
    // Scheduled debit indicators
    "will be debited", "will be charged", "will be deducted",
    "shall be debited", "to be debited",
    // e-Mandate / NACH / SI patterns
    "e.?mandate", "nach debit", "standing instruction", "auto.?debit",
    "ecs debit", "si execution", "mandate.*due", "mandate.*scheduled",
    // Due / reminder language
    "is due", "are due", "due on", "due date", "payment due",
    "reminder", "upcoming payment", "scheduled.*debit", "debit.*scheduled",
    // Alert / limit / balance language (not a transaction)
    "low balance", "minimum balance", "balance alert", "credit limit",
    "limit.*reached", "limit.*exceeded", "available limit",
    // Approval requests
    "approve.*transaction", "authorise", "authorize.*payment"
].joined(separator: "|")

nonisolated private func isFutureOrAlertMessage(_ text: String) -> Bool {
    text.range(of: futureTensePattern, options: [.regularExpression, .caseInsensitive]) != nil
}

// MARK: - Legitimacy Filter
// Rejects promotional / scam messages that contain ₹ or Rs. but aren't real transactions.
// A legitimate bank transaction SMS must have BOTH:
//   1. A transaction verb (debited/credited/paid/spent etc.)
//   2. A structured amount pattern (currency symbol immediately followed by digits)

nonisolated(unsafe) private let transactionVerbPattern = [
    "debited", "credited", "spent", "deducted", "withdrawn",
    "paid", "sent", "received", "deposited", "refund",
    "transferred", "charged", "txn", "transaction", "purchase",
    "a/c", "acct", "account", "your.*card", "upi", "neft", "imps", "rtgs"
].joined(separator: "|")

nonisolated private func isLikelyBankSMS(_ text: String) -> Bool {
    let lower = text.lowercased()
    // Must contain at least one transaction verb
    guard lower.range(of: transactionVerbPattern, options: .regularExpression) != nil else {
        return false
    }
    // Must contain a structured amount (currency prefix + digits, not just a loose number)
    let amountPattern = "(?:rs\\.?|inr|₹)\\s*[\\d,]+"
    guard lower.range(of: amountPattern, options: .regularExpression) != nil else {
        return false
    }
    // Reject obvious promotional patterns
    let promoPattern = "offer|discount|cashback|reward|win|prize|congratul|voucher|coupon|deal|sale|off on|lucky|selected|click|link|http|www\\."
    if lower.range(of: promoPattern, options: .regularExpression) != nil {
        // Only reject if NO account/card reference (real banks sometimes mention cashback too)
        let hasAccountRef = lower.range(of: "a/c|acct|account|card|upi|neft|imps", options: .regularExpression) != nil
        if !hasAccountRef { return false }
    }
    return true
}

// MARK: - Amount Extraction
// Handles both formats:
//   - Currency-prefix:  "Rs.500", "INR 343", "₹1,200.50"
//   - Currency-suffix:  "500 INR", "343 Rs" (rare but seen in some banks)

nonisolated private func extractAmount(from text: String) -> Double? {
    // Primary: currency symbol/code BEFORE the number (most common)
    let prefixPattern = "(?:Rs\\.?|INR|₹)\\s*([\\d,]+(?:\\.\\d{1,2})?)"
    // Secondary: number BEFORE INR/Rs (e.g. Bank of Baroda "INR 343 spent" also matches prefix,
    // but some edge cases send "343.00 INR")
    let suffixPattern = "([\\d,]+(?:\\.\\d{1,2})?)\\s*(?:INR|Rs\\.?)"

    func parseNumber(_ raw: String) -> Double? {
        let cleaned = raw.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard let amount = Double(cleaned), amount > 0, amount < 10_000_000 else { return nil }
        return amount
    }

    // Try prefix match first
    if let match = text.range(of: prefixPattern, options: .regularExpression) {
        let matchedString = String(text[match])
        let numberString = matchedString
            .replacingOccurrences(of: "Rs.", with: "")
            .replacingOccurrences(of: "Rs", with: "")
            .replacingOccurrences(of: "INR", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .trimmingCharacters(in: .whitespaces)
        if let amount = parseNumber(numberString) { return amount }
    }

    // Fallback: suffix match
    if let regex = try? NSRegularExpression(pattern: suffixPattern),
       let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
       match.numberOfRanges > 1,
       let range = Range(match.range(at: 1), in: text) {
        return parseNumber(String(text[range]))
    }

    return nil
}

// MARK: - Transaction Type Detection

nonisolated(unsafe) private let debitKeywords = [
    "debited", "debit", "spent", "deducted", "withdrawn",
    "paid", "sent", "transferred out", "charged", "txn debited",
    "purchase", "payment of", "used at", "used for"
]

nonisolated(unsafe) private let creditKeywords = [
    "credited", "credit", "received", "deposited", "refund",
    "has been credited", "money added", "transfer in", "cashback"
]

nonisolated private func extractType(from text: String) -> String {
    let lower = text.lowercased()
    for kw in debitKeywords where lower.contains(kw) { return "debit" }
    for kw in creditKeywords where lower.contains(kw) { return "credit" }
    return "debit"
}

// MARK: - Bank Detection

private struct BankEntry {
    let keywords: [String]
    let name: String
}

nonisolated(unsafe) private let bankEntries: [BankEntry] = [
    BankEntry(keywords: ["hdfc", "hdfcbk"], name: "HDFC"),
    BankEntry(keywords: ["icici", "icicib"], name: "ICICI"),
    BankEntry(keywords: ["sbi", "sbiinb", "sbipsg"], name: "SBI"),
    BankEntry(keywords: ["canara", "canarabank", "cnrbnk"], name: "Canara"),
    BankEntry(keywords: ["axis", "axisbk", "axisbank"], name: "Axis"),
    BankEntry(keywords: ["kotak", "kotakbk"], name: "Kotak"),
    BankEntry(keywords: ["indusind", "indusbnk"], name: "IndusInd"),
    BankEntry(keywords: ["yes bank", "yesbank", "yesbk"], name: "Yes Bank"),
    BankEntry(keywords: ["pnb", "pnbsms"], name: "PNB"),
    BankEntry(keywords: ["bob", "bankofbaroda", "barodabnk"], name: "Bank of Baroda"),
    BankEntry(keywords: ["idfc", "idfcbk"], name: "IDFC First"),
    BankEntry(keywords: ["federal", "fedbnk"], name: "Federal Bank"),
    BankEntry(keywords: ["amex", "americanexpress"], name: "Amex"),
    BankEntry(keywords: ["paytm"], name: "Paytm"),
    BankEntry(keywords: ["jupiter"], name: "Jupiter"),
    BankEntry(keywords: ["fi ", "fi-"], name: "Fi"),
]

nonisolated private func extractBank(from text: String, sender: String) -> String {
    let senderLower = sender.lowercased()
    let textLower = text.lowercased()
    for entry in bankEntries {
        for kw in entry.keywords where senderLower.contains(kw) { return entry.name }
    }
    for entry in bankEntries {
        for kw in entry.keywords where textLower.contains(kw) { return entry.name }
    }
    return "Bank"
}

// MARK: - Merchant Extraction

nonisolated private func extractMerchant(from text: String, bank: String) -> String {
    let patterns = [
        // "at MERCHANT on", "to MERCHANT on", "for MERCHANT"
        "(?:at|to|for|towards|Info:|trf to)\\s+([A-Za-z0-9][A-Za-z0-9\\s\\-&'.\\/]{2,50}?)(?:\\s+on\\s|\\s+via\\s|\\s+Ref|\\s+ref|\\.|,|\\n|$)",
        // "UPI/NEFT/IMPS: MERCHANT"
        "(?:UPI|NEFT|IMPS|RTGS)[:\\-\\s]+([A-Za-z0-9][A-Za-z0-9\\s\\-&'.]{2,40}?)(?:\\s+on\\s|\\.|,|\\n|$)",
        // VPA handle
        "VPA[:\\s]+([a-z0-9._]+@[a-z]+)",
        // "MERCHANT@upi" style
        "([A-Za-z0-9._]{3,30}@(?:okaxis|oksbi|okicici|okhdfcbank|ybl|axl|ibl|upi|paytm|freecharge|jiomoney))",
    ]

    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
        let nsText = text as NSString
        if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
           match.numberOfRanges > 1 {
            let range = match.range(at: 1)
            if range.location != NSNotFound {
                let merchant = nsText.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
                if !merchant.isEmpty { return merchant }
            }
        }
    }
    return "\(bank) Transaction"
}

// MARK: - Account Extraction

nonisolated private func extractAccount(from text: String, bank: String) -> String {
    let pattern = "(?:[Aa]\\/[Cc]|[Aa]ccount|[Cc]ard)[^0-9]*(?:XX+|x+|\\*+)?(\\d{4})"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return "" }
    let nsText = text as NSString
    if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
       match.numberOfRanges > 1 {
        let range = match.range(at: 1)
        if range.location != NSNotFound {
            return "\(bank) ••\(nsText.substring(with: range))"
        }
    }
    return ""
}

// MARK: - Main Entry Point

nonisolated func parseSMS(text: String, sender: String, receivedAt: Date) -> ParsedSMSTransaction? {
    guard !isOTPMessage(text) else { return nil }
    guard !isFutureOrAlertMessage(text) else { return nil }   // ← rejects mandates / alerts
    guard isLikelyBankSMS(text) else { return nil }
    guard let amount = extractAmount(from: text) else { return nil }

    let type = extractType(from: text)
    let bank = extractBank(from: text, sender: sender)
    let merchant = extractMerchant(from: text, bank: bank)
    let account = extractAccount(from: text, bank: bank)

    return ParsedSMSTransaction(
        amount: amount,
        type: type,
        merchant: merchant,
        bank: bank,
        account: account,
        date: receivedAt
    )
}

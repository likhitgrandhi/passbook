import Foundation

// MARK: - Merchant Map

nonisolated(unsafe) private let merchantMap: [(keywords: [String], category: String)] = [
    (["swiggy", "zomato", "bigbasket", "blinkit", "zepto", "starbucks", "mcdonald"], "Food & Dining"),
    (["uber", "ola", "rapido", "metro", "bmtc", "dtc", "irctc", "fasttag"], "Auto & Transport"),
    (["amazon", "flipkart", "myntra", "nykaa", "ajio", "meesho"], "Shopping"),
    (["netflix", "spotify", "hotstar", "disney", "jio", "airtel", "youtube premium",
      "apple music", "microsoft 365", "google one"], "Subscriptions"),
    (["apollo", "practo", "1mg", "netmeds", "cult.fit", "gym", "hospital", "pharmacy"], "Health & Wellness"),
    (["bookmyshow", "pvr", "inox", "steam", "playstation"], "Entertainment"),
    (["bescom", "tata power", "electricity", "rent", "landlord", "broadband",
      "act fibernet", "gas"], "Housing"),
    (["coursera", "udemy", "unacademy", "byju", "school", "college"], "Education"),
    (["zerodha", "groww", "upstox", "mutual fund", "sip", "nps", "lic"], "Investments"),
    (["indigo", "air india", "spicejet", "oyo", "makemytrip", "goibibo"], "Travel & Vacation"),
    (["neft", "rtgs", "imps", "credit card payment"], "Transfers"),
]

// MARK: - Keyword Fallback Map

private struct KeywordCategory {
    let pattern: String
    let category: String
}

nonisolated(unsafe) private let keywordFallbacks: [KeywordCategory] = [
    KeywordCategory(pattern: "food|lunch|dinner|restaurant|cafe|bakery", category: "Food & Dining"),
    KeywordCategory(pattern: "cab|taxi|ride|auto|bus|train|flight|toll|fuel", category: "Auto & Transport"),
    KeywordCategory(pattern: "movie|cinema|theatre|concert|event|ticket", category: "Entertainment"),
    KeywordCategory(pattern: "gym|yoga|fitness|health", category: "Health & Wellness"),
    KeywordCategory(pattern: "medical|medicine|doctor|hospital|clinic|pharmacy", category: "Health & Wellness"),
    KeywordCategory(pattern: "hotel|resort|stay|accommodation", category: "Travel & Vacation"),
    KeywordCategory(pattern: "rent|maintenance|electricity|water|internet", category: "Housing"),
    KeywordCategory(pattern: "subscription|premium|pro|membership", category: "Subscriptions"),
    KeywordCategory(pattern: "invest|mutual|stock|share|bond", category: "Investments"),
    KeywordCategory(pattern: "transfer|neft|imps|rtgs|upi", category: "Transfers"),
]

// MARK: - Public Entry Point

nonisolated func categorize(merchant: String) -> String {
    let lower = merchant.lowercased()

    // Merchant map — case-insensitive contains match
    for entry in merchantMap {
        for keyword in entry.keywords where lower.contains(keyword) {
            return entry.category
        }
    }

    // Keyword regex fallback
    for fallback in keywordFallbacks {
        if lower.range(of: fallback.pattern, options: .regularExpression) != nil {
            return fallback.category
        }
    }

    return "Other"
}

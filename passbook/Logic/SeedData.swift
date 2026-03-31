
import Foundation

// swiftlint:disable function_body_length
func makeSeedTransactions() -> [Transaction] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)

    func daysAgo(_ n: Int) -> Date {
        cal.date(byAdding: .day, value: -n, to: today) ?? today
    }

    func dateAt(_ daysBack: Int, hour: Int, minute: Int = 0) -> Date {
        let base = daysAgo(daysBack)
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }

    return [
        // Day 0 - Today
        Transaction(date: dateAt(0, hour: 8, minute: 30), amount: 249, type: "debit",
                    merchant: "Swiggy", category: "Food", source: "seed"),
        Transaction(date: dateAt(0, hour: 10, minute: 15), amount: 85, type: "debit",
                    merchant: "Namma Metro", category: "Transport", source: "seed"),
        Transaction(date: dateAt(0, hour: 14, minute: 0), amount: 1299, type: "debit",
                    merchant: "Amazon", category: "Shopping", source: "seed"),

        // Day 1
        Transaction(date: dateAt(1, hour: 9, minute: 0), amount: 199, type: "debit",
                    merchant: "Zomato", category: "Food", source: "seed"),
        Transaction(date: dateAt(1, hour: 11, minute: 30), amount: 320, type: "debit",
                    merchant: "Uber", category: "Transport", source: "seed"),
        Transaction(date: dateAt(1, hour: 19, minute: 0), amount: 149, type: "debit",
                    merchant: "Netflix", category: "Entertainment",
                    subcategory: "Streaming", isRecurring: true, source: "seed"),

        // Day 2
        Transaction(date: dateAt(2, hour: 8, minute: 0), amount: 450, type: "debit",
                    merchant: "BigBasket", category: "Food", source: "seed"),
        Transaction(date: dateAt(2, hour: 13, minute: 45), amount: 600, type: "debit",
                    merchant: "Ola", category: "Transport", source: "seed"),
        Transaction(date: dateAt(2, hour: 20, minute: 0), amount: 799, type: "debit",
                    merchant: "Myntra", category: "Shopping", source: "seed"),

        // Day 3
        Transaction(date: dateAt(3, hour: 7, minute: 30), amount: 119, type: "debit",
                    merchant: "Spotify", category: "Entertainment", isRecurring: true, source: "seed"),
        Transaction(date: dateAt(3, hour: 12, minute: 0), amount: 380, type: "debit",
                    merchant: "Swiggy", category: "Food", source: "seed"),
        Transaction(date: dateAt(3, hour: 17, minute: 15), amount: 499, type: "debit",
                    merchant: "Apollo Pharmacy", category: "Health", source: "seed"),

        // Day 4
        Transaction(date: dateAt(4, hour: 9, minute: 30), amount: 1599, type: "debit",
                    merchant: "Flipkart", category: "Shopping", source: "seed"),
        Transaction(date: dateAt(4, hour: 14, minute: 0), amount: 220, type: "debit",
                    merchant: "McDonald's", category: "Food", source: "seed"),
        Transaction(date: dateAt(4, hour: 18, minute: 0), amount: 2000, type: "debit",
                    merchant: "BESCOM", category: "Utilities", isRecurring: true, source: "seed"),

        // Day 5
        Transaction(date: dateAt(5, hour: 8, minute: 0), amount: 75, type: "debit",
                    merchant: "BMTC", category: "Transport", source: "seed"),
        Transaction(date: dateAt(5, hour: 12, minute: 30), amount: 650, type: "debit",
                    merchant: "Starbucks", category: "Food", source: "seed"),
        Transaction(date: dateAt(5, hour: 16, minute: 0), amount: 999, type: "debit",
                    merchant: "BookMyShow", category: "Entertainment", source: "seed"),

        // Day 6
        Transaction(date: dateAt(6, hour: 10, minute: 0), amount: 1200, type: "debit",
                    merchant: "Airtel", category: "Utilities", isRecurring: true, source: "seed"),
        Transaction(date: dateAt(6, hour: 13, minute: 0), amount: 340, type: "debit",
                    merchant: "Zomato", category: "Food", source: "seed"),
        Transaction(date: dateAt(6, hour: 19, minute: 30), amount: 2499, type: "debit",
                    merchant: "Nykaa", category: "Shopping", source: "seed"),

        // Day 7
        Transaction(date: dateAt(7, hour: 9, minute: 0), amount: 500, type: "debit",
                    merchant: "Cult.fit", category: "Health", isRecurring: true, source: "seed"),
        Transaction(date: dateAt(7, hour: 14, minute: 30), amount: 180, type: "debit",
                    merchant: "Uber", category: "Transport", source: "seed"),
        Transaction(date: dateAt(7, hour: 20, minute: 0), amount: 299, type: "debit",
                    merchant: "Swiggy", category: "Food", source: "seed"),

        // Day 9
        Transaction(date: dateAt(9, hour: 11, minute: 0), amount: 799, type: "debit",
                    merchant: "Steam", category: "Entertainment", source: "seed"),
        Transaction(date: dateAt(9, hour: 15, minute: 30), amount: 350, type: "debit",
                    merchant: "BigBasket", category: "Food", source: "seed"),
        Transaction(date: dateAt(9, hour: 18, minute: 0), amount: 400, type: "debit",
                    merchant: "Jio", category: "Utilities", isRecurring: true, source: "seed"),

        // Day 11
        Transaction(date: dateAt(11, hour: 9, minute: 0), amount: 3500, type: "debit",
                    merchant: "Amazon", category: "Shopping", source: "seed"),
        Transaction(date: dateAt(11, hour: 13, minute: 30), amount: 270, type: "debit",
                    merchant: "McDonald's", category: "Food", source: "seed"),
        Transaction(date: dateAt(11, hour: 17, minute: 0), amount: 250, type: "debit",
                    merchant: "Namma Metro", category: "Transport", source: "seed"),

        // Day 13
        Transaction(date: dateAt(13, hour: 10, minute: 0), amount: 800, type: "debit",
                    merchant: "Practo", category: "Health", source: "seed"),
        Transaction(date: dateAt(13, hour: 14, minute: 0), amount: 420, type: "debit",
                    merchant: "Zomato", category: "Food", source: "seed"),
        Transaction(date: dateAt(13, hour: 19, minute: 0), amount: 560, type: "debit",
                    merchant: "Ola", category: "Transport", source: "seed"),

        // Day 15
        Transaction(date: dateAt(15, hour: 8, minute: 30), amount: 189, type: "debit",
                    merchant: "Swiggy", category: "Food", source: "seed"),
        Transaction(date: dateAt(15, hour: 12, minute: 0), amount: 4999, type: "debit",
                    merchant: "Flipkart", category: "Shopping", source: "seed"),
        Transaction(date: dateAt(15, hour: 20, minute: 30), amount: 149, type: "debit",
                    merchant: "Netflix", category: "Entertainment", isRecurring: true, source: "seed"),

        // Day 18
        Transaction(date: dateAt(18, hour: 9, minute: 0), amount: 300, type: "debit",
                    merchant: "Apollo Pharmacy", category: "Health", source: "seed"),
        Transaction(date: dateAt(18, hour: 13, minute: 0), amount: 750, type: "debit",
                    merchant: "Starbucks", category: "Food", source: "seed"),
        Transaction(date: dateAt(18, hour: 16, minute: 30), amount: 1499, type: "debit",
                    merchant: "Myntra", category: "Shopping", source: "seed"),

        // Day 21
        Transaction(date: dateAt(21, hour: 10, minute: 0), amount: 500, type: "debit",
                    merchant: "BookMyShow", category: "Entertainment", source: "seed"),
        Transaction(date: dateAt(21, hour: 14, minute: 0), amount: 200, type: "debit",
                    merchant: "BMTC", category: "Transport", source: "seed"),
        Transaction(date: dateAt(21, hour: 19, minute: 0), amount: 390, type: "debit",
                    merchant: "BigBasket", category: "Food", source: "seed"),

        // Day 24
        Transaction(date: dateAt(24, hour: 9, minute: 30), amount: 1000, type: "debit",
                    merchant: "Cult.fit", category: "Health", isRecurring: true, source: "seed"),
        Transaction(date: dateAt(24, hour: 15, minute: 0), amount: 850, type: "debit",
                    merchant: "Amazon", category: "Shopping", source: "seed"),

        // Day 27
        Transaction(date: dateAt(27, hour: 11, minute: 0), amount: 480, type: "debit",
                    merchant: "Zomato", category: "Food", source: "seed"),
        Transaction(date: dateAt(27, hour: 16, minute: 0), amount: 300, type: "debit",
                    merchant: "Uber", category: "Transport", source: "seed"),
        Transaction(date: dateAt(27, hour: 20, minute: 0), amount: 119, type: "debit",
                    merchant: "Spotify", category: "Entertainment", isRecurring: true, source: "seed"),

        // Day 29
        Transaction(date: dateAt(29, hour: 9, minute: 0), amount: 600, type: "debit",
                    merchant: "Airtel", category: "Utilities", isRecurring: true, source: "seed"),
        Transaction(date: dateAt(29, hour: 14, minute: 30), amount: 165, type: "debit",
                    merchant: "McDonald's", category: "Food", source: "seed"),
        Transaction(date: dateAt(29, hour: 18, minute: 0), amount: 2200, type: "debit",
                    merchant: "Nykaa", category: "Shopping", source: "seed"),
    ]
}

import SwiftData

@MainActor
struct SharedModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([Transaction.self, Budget.self, PassbookSubscription.self, SMSLog.self, MonthlyBudget.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}

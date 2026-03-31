import AppIntents

struct PassbookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTransactionIntent(),
            phrases: [
                "Log transaction in \(.applicationName)",
                "Add bank SMS to \(.applicationName)"
            ],
            shortTitle: "Log Bank Transaction",
            systemImageName: "indianrupeesign.circle"
        )
    }
}

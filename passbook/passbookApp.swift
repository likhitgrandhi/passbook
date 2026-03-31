
import SwiftUI
import SwiftData

@main
struct passbookApp: App {
    @State private var store = TransactionStore()


    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .modelContainer(SharedModelContainer.shared)
    }
}

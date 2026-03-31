import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var granularity: Granularity = .day

    private var overviewLabel: String {
        switch granularity {
        case .day:   return "Today"
        case .week:  return "Week"
        case .month: return "Month"
        }
    }

    private var overviewIcon: String {
        switch granularity {
        case .day:   return "sun.max.fill"
        case .week:  return "calendar.badge.clock"
        case .month: return "moon.fill"
        }
    }

    var body: some View {
        TabView {
            Tab(overviewLabel, systemImage: overviewIcon) {
                SquaresDayHomeView(granularity: $granularity)
            }

            Tab("Budget", systemImage: "chart.pie") {
                BudgetView()
            }
        }
        .sensoryFeedback(.selection, trigger: granularity)
    }
}

#Preview {
    ContentView()
        .environment(TransactionStore())
        .modelContainer(SharedModelContainer.shared)
}

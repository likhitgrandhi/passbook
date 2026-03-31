
import SwiftUI


/// A single glass circle showing the current granularity icon.
/// Long-press opens a context menu to switch between Day / Week / Month.
struct GranularityPillView: View {
    @Binding var granularity: Granularity
    let onGranularityChange: () -> Void

    private var currentIcon: String {
        switch granularity {
        case .day:   return "sun.max.fill"
        case .week:  return "calendar.badge.clock"
        case .month: return "moon.fill"
        }
    }

    private var currentLabel: String {
        switch granularity {
        case .day:   return "Day"
        case .week:  return "Week"
        case .month: return "Month"
        }
    }

    private let options: [(Granularity, String, String)] = [
        (.day,   "sun.max.fill",            "Day"),
        (.week,  "calendar.badge.clock",    "Week"),
        (.month, "moon.fill",               "Month"),
    ]

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { gran, icon, label in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        granularity = gran
                    }
                    onGranularityChange()
                } label: {
                    Label(label, systemImage: icon)
                }
                .disabled(granularity == gran)
            }
        } label: {
            Image(systemName: currentIcon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppColors.charcoal)
                .frame(width: 44, height: 44)
                .contentTransition(.symbolEffect(.replace))
        } primaryAction: {
            //  zxz Single tap cycles to next granularity
            let order: [Granularity] = [.day, .week, .month]
            if let idx = order.firstIndex(of: granularity) {
                let next = order[(idx + 1) % order.count]
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    granularity = next
                }
                onGranularityChange()
            }
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .sensoryFeedback(.selection, trigger: granularity)
    }
}

#Preview {
    GranularityPillView(granularity: .constant(.day), onGranularityChange: {})
        .padding()
        .background(AppColors.homeBlue)
}

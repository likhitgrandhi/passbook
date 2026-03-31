
import SwiftUI


struct HeroAmountView: View {
    let headline: String
    let amount: Double
    @Binding var granularity: Granularity
    let onGranularityChange: () -> Void

    private let options: [(Granularity, String, String)] = [
        (.day,   "sun.max",              "Today"),
        (.week,  "calendar.badge.clock", "Week"),
        (.month, "moon",                 "Month"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Tappable headline — opens granularity picker
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
                HStack(spacing: 4) {
                    Text(headline)
                        .font(.caption.weight(.medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(AppColors.charcoal.opacity(0.75))
            }

            Text(compactINR(amount))
                .font(.custom("Sora-SemiBold", size: 90))
                .tracking(-3.6)
                .monospacedDigit()
                .foregroundStyle(AppColors.charcoal)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sensoryFeedback(.selection, trigger: granularity)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

#Preview {
    HeroAmountView(headline: "Today", amount: 1633, granularity: .constant(.day), onGranularityChange: {})
        .background(AppColors.homeBlue)
}


import SwiftUI

private let barWidth: Double  = 44
private let maxBarHeight: Double = 160
private let minBarHeight: Double = 17

struct SpendingBarView: View {
    let bar: ChartBar
    let maxAmount: Double
    let isSelected: Bool
    let onTap: () -> Void

    private var barHeight: Double {
        guard maxAmount > 0, bar.amount > 0 else { return minBarHeight }
        return max(minBarHeight, (bar.amount / maxAmount) * maxBarHeight)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Amount label + bar, bottom-aligned in fixed-height container
                VStack(spacing: 4) {
                    Spacer(minLength: 0)

                    Text(bar.amount > 0 ? compactINR(bar.amount) : " ")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: barWidth)

                    RoundedRectangle(cornerRadius: 7)
                        .fill(AppColors.charcoal)
                        .frame(width: barWidth, height: barHeight)
                        .scaleEffect(x: isSelected ? 1.06 : 1.0, y: 1.0, anchor: .bottom)
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(.white.opacity(0.7), lineWidth: 2)
                                    .shadow(color: .white.opacity(0.5), radius: 4)
                            }
                        }
                        .animation(.spring(duration: 0.2), value: isSelected)
                }
                .frame(width: barWidth, height: maxBarHeight + 20)

                // Day/week/month label below bar
                Text(bar.label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.charcoal.opacity(0.75))
                    .frame(width: barWidth)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(bar.label), \(bar.amount > 0 ? compactINR(bar.amount) : "no spend")")
    }
}

#Preview {
    HStack(alignment: .bottom, spacing: 12) {
        SpendingBarView(
            bar: ChartBar(id: "1", label: "Mon", amount: 1200, periodStart: .now, periodEnd: .now),
            maxAmount: 2000, isSelected: false, onTap: {}
        )
        SpendingBarView(
            bar: ChartBar(id: "2", label: "Tue", amount: 400, periodStart: .now, periodEnd: .now),
            maxAmount: 2000, isSelected: false, onTap: {}
        )
        SpendingBarView(
            bar: ChartBar(id: "3", label: "Wed", amount: 1800, periodStart: .now, periodEnd: .now),
            maxAmount: 2000, isSelected: true, onTap: {}
        )
    }
    .padding(20)
    .background(AppColors.homeBlue)
}

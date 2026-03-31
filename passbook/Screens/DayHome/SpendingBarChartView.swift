
import SwiftUI

struct SpendingBarChartView: View {
    let bars: [ChartBar]
    @Binding var focusedBarID: String?

    private var maxAmount: Double {
        bars.map(\.amount).max() ?? 1
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(bars) { bar in
                    SpendingBarView(
                        bar: bar,
                        maxAmount: maxAmount,
                        isSelected: focusedBarID == bar.id,
                        onTap: {
                            focusedBarID = focusedBarID == bar.id ? nil : bar.id
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.trailing)
    }
}

#Preview {
    let bars = (0..<7).map { i -> ChartBar in
        ChartBar(
            id: "\(i)",
            label: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][i],
            amount: Double([1200, 800, 1700, 500, 2100, 950, 1400][i]),
            periodStart: .now,
            periodEnd: .now
        )
    }
    SpendingBarChartView(bars: bars, focusedBarID: .constant(nil))
        .background(AppColors.homeBlue)
}

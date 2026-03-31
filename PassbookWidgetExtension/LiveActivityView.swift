import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Activity Attributes

struct TransactionActivityAttributes: ActivityAttributes {
    let merchant: String
    let categoryEmoji: String

    struct ContentState: Codable, Hashable {
        let transactionAmount: Double
        let budgetSpentFraction: Double
        let dailyBudgetRemaining: Double
        let isOverBudget: Bool
    }
}

// MARK: - Widget

struct PassbookLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransactionActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailing(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(state: context.state)
                }
            } compactLeading: {
                Text(context.attributes.categoryEmoji)
                    .font(.system(size: 15))
            } compactTrailing: {
                Text(compactINR(context.state.transactionAmount))
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(spendColor(context.state))
            } minimal: {
                Text(context.attributes.categoryEmoji)
                    .font(.system(size: 14))
            }
        }
    }
}

// MARK: - Lock Screen (banner on older iPhones)

private struct LockScreenView: View {
    let context: ActivityViewContext<TransactionActivityAttributes>

    var body: some View {
        VStack(spacing: 0) {
            // Row 1 — merchant + amount
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    Text(context.attributes.categoryEmoji)
                        .font(.system(size: 24))
                    Text(context.attributes.merchant)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(spendColor(context.state))
                    Text(compactINR(context.state.transactionAmount))
                        .font(.system(size: 20, weight: .black).monospacedDigit())
                        .foregroundStyle(spendColor(context.state))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // Row 2 — progress bar + remaining pill
            HStack(spacing: 12) {
                BudgetBar(fraction: context.state.budgetSpentFraction, isOver: context.state.isOverBudget)

                // Remaining pill
                Text(compactINR(context.state.dailyBudgetRemaining) + " left")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(spendColor(context.state))
                    )
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.black)
    }
}

// MARK: - Expanded Leading

private struct ExpandedLeading: View {
    let context: ActivityViewContext<TransactionActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.categoryEmoji)
                .font(.system(size: 28))
            Text(context.attributes.merchant)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
        .padding(.leading, 4)
        .padding(.top, 4)
    }
}

// MARK: - Expanded Trailing

private struct ExpandedTrailing: View {
    let state: TransactionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(spendColor(state))
                Text(compactINR(state.transactionAmount))
                    .font(.system(size: 22, weight: .black).monospacedDigit())
                    .foregroundStyle(spendColor(state))
            }
            Text("debited")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.trailing, 4)
        .padding(.top, 4)
    }
}

// MARK: - Expanded Bottom

private struct ExpandedBottom: View {
    let state: TransactionActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.bottom, 10)

            HStack(spacing: 12) {
                BudgetBar(fraction: state.budgetSpentFraction, isOver: state.isOverBudget)

                // Remaining pill — like the gate tag in the airline example
                Text(compactINR(state.dailyBudgetRemaining) + " left")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(spendColor(state)))
                    .fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Budget Progress Bar

private struct BudgetBar: View {
    let fraction: Double
    let isOver: Bool

    private var clamped: Double { min(fraction, 1.0) }
    private var fill: Color { spendColor(isOver: isOver, fraction: fraction) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 8)

                // Glow
                Capsule()
                    .fill(fill.opacity(0.3))
                    .frame(width: geo.size.width * clamped, height: 8)
                    .blur(radius: 3)

                // Fill
                Capsule()
                    .fill(LinearGradient(
                        colors: [fill.opacity(0.7), fill],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * clamped, height: 8)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Color Helpers

private func spendColor(_ state: TransactionActivityAttributes.ContentState) -> Color {
    spendColor(isOver: state.isOverBudget, fraction: state.budgetSpentFraction)
}

private func spendColor(isOver: Bool, fraction: Double) -> Color {
    if isOver { return Color(red: 1.0, green: 0.30, blue: 0.30) }
    if fraction > 0.85 { return Color(red: 1.0, green: 0.75, blue: 0.10) }
    return Color(red: 0.20, green: 0.85, blue: 0.45) // green for healthy spend
}

// MARK: - Formatting

private func compactINR(_ amount: Double) -> String {
    if amount >= 100_000 { return "₹\(fmt(amount / 100_000))L" }
    if amount >= 1_000   { return "₹\(fmt(amount / 1_000))K" }
    return "₹\(Int(amount))"
}

private func fmt(_ value: Double) -> String {
    let r = (value * 10).rounded() / 10
    return r == r.rounded(.towardZero) ? "\(Int(r))" : String(format: "%.1f", r)
}

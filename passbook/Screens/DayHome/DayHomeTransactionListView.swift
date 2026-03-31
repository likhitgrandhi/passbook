
import SwiftUI


// MARK: - Filter options

private enum TransactionFilter: String, CaseIterable {
    case all      = "All Transactions"
    case category = "By Category"
}

// MARK: - Card shell

struct TransactionCard: View {
    let transactions: [Transaction]
    let isExpanded: Bool
    @Binding var scrollOffset: CGFloat

    @State private var filter: TransactionFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(AppColors.charcoal.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Filter label
            HStack {
                FilterLabel(filter: $filter)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // List — no divider above it
            TransactionListBody(
                transactions: transactions,
                filter: filter,
                isExpanded: isExpanded,
                scrollOffset: $scrollOffset
            )
        }
        .background(.white)
    }
}

// MARK: - Filter label

private struct FilterLabel: View {
    @Binding var filter: TransactionFilter

    var body: some View {
        Menu {
            ForEach(TransactionFilter.allCases, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        filter = option
                    }
                } label: {
                    if filter == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(filter.rawValue)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColors.charcoal)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.charcoal.opacity(0.5))
            }
        }
    }
}

// MARK: - List body

private struct TransactionListBody: View {
    let transactions: [Transaction]
    let filter: TransactionFilter
    let isExpanded: Bool
    @Binding var scrollOffset: CGFloat

    // Filter applied here, not in body, to avoid inline transform on every eval
    private var displayed: [Transaction] {
        let base: [Transaction]
        switch filter {
        case .all:
            base = transactions
        case .category:
            base = transactions.sorted { $0.category < $1.category }
        }
        return Array(base.prefix(30))
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(displayed.enumerated(), id: \.element.id) { index, transaction in
                    TappableTransactionRow(transaction: transaction)
                    if index < displayed.count - 1 {
                        Rectangle()
                            .fill(AppColors.charcoal.opacity(0.07))
                            .frame(height: 0.5)
                            .padding(.horizontal, 20)
                    }
                }
                Color.clear.frame(height: 40)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, newValue in
            scrollOffset = -newValue
        }
        .scrollDisabled(!isExpanded)
        .scrollIndicators(.hidden)
    }
}

// MARK: - Category icon

private struct CategoryIcon: View {
    let category: String

    private var symbol: String {
        switch category {
        case "Food & Dining":       return "fork.knife"
        case "Auto & Transport":    return "car.fill"
        case "Shopping":            return "bag.fill"
        case "Subscriptions":       return "play.rectangle.fill"
        case "Health & Wellness":   return "heart.fill"
        case "Entertainment":       return "ticket.fill"
        case "Housing":             return "house.fill"
        case "Education":           return "book.fill"
        case "Investments":         return "chart.line.uptrend.xyaxis"
        case "Travel & Vacation":   return "airplane"
        case "Transfers":           return "arrow.left.arrow.right"
        default:                    return "creditcard.fill"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColors.charcoal.opacity(0.45))
            .accessibilityHidden(true)
    }
}

// MARK: - Tappable wrapper

private struct TappableTransactionRow: View {
    let transaction: Transaction
    @State private var showDrawer = false

    var body: some View {
        Button {
            showDrawer = true
        } label: {
            TransactionRowView(transaction: transaction)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDrawer) {
            TransactionDetailDrawer(transaction: transaction)
                .presentationDetents([.height(580), .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
        }
    }
}

// MARK: - Transaction row

private struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        let dimmed = transaction.excludedFromCalc

        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    CategoryIcon(category: transaction.category)
                    Text(transaction.category)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal.opacity(dimmed ? 0.22 : 0.40))
                }
                Text(transaction.merchant)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.charcoal.opacity(dimmed ? 0.30 : 1.0))
                Text(transaction.date, format: .dateTime.hour().minute())
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(AppColors.charcoal.opacity(dimmed ? 0.18 : 0.35))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(compactINR(transaction.amount))
                    .font(.custom("Sora-SemiBold", size: 22))
                    .foregroundStyle(AppColors.charcoal.opacity(dimmed ? 0.28 : 1.0))

                // Single view with ternary values — preserves structural identity
                // so SwiftUI never recreates the badge view when dimmed toggles
                let isCredit = transaction.type == "credit"
                let badgeText  = dimmed ? "EXCLUDED" : (isCredit ? "CREDIT" : "DEBIT")
                let badgeFg: Color = dimmed
                    ? AppColors.charcoal.opacity(0.28)
                    : isCredit ? Color(red: 0.10, green: 0.62, blue: 0.40)
                    : AppColors.charcoal.opacity(0.45)
                let badgeBg: Color = dimmed
                    ? AppColors.charcoal.opacity(0.07)
                    : isCredit ? Color(red: 0.10, green: 0.62, blue: 0.40).opacity(0.12)
                    : AppColors.charcoal.opacity(0.07)

                Text(badgeText)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(badgeFg)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(badgeBg))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(transaction.merchant), \(transaction.category), \(compactINR(transaction.amount)), \(transaction.type)"
        )
    }
}

#Preview {
    @Previewable @State var offset: CGFloat = 0
    let txns = [
        Transaction(date: .now, amount: 249,  type: "debit",  merchant: "Swiggy",   category: "Food & Dining"),
        Transaction(date: .now, amount: 320,  type: "debit",  merchant: "Uber",      category: "Auto & Transport"),
        Transaction(date: .now, amount: 1299, type: "credit", merchant: "Salary",    category: "Transfers"),
        Transaction(date: .now, amount: 599,  type: "debit",  merchant: "Netflix",   category: "Subscriptions"),
    ]
    ZStack {
        AppColors.homeBlue.ignoresSafeArea()
        TransactionCard(transactions: txns, isExpanded: false, scrollOffset: $offset)
            .offset(y: 280)
    }
}

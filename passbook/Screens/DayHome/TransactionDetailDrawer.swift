
import SwiftUI
import SwiftData


private struct PendingCategoryChange: Identifiable {
    let id = UUID()
    let newCategory: String
    let otherCount: Int
}

// MARK: - Drawer

struct TransactionDetailDrawer: View {
    let transaction: Transaction
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isExcluded: Bool = false
    @State private var confirmDelete = false
    @State private var showCategoryPicker = false
    @State private var pendingCategoryChange: PendingCategoryChange? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM dd, yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {

            // ── Handle ──────────────────────────────────────────────────
            Capsule()
                .fill(AppColors.charcoal.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // ── Navigation bar row ───────────────────────────────────────
            ZStack {
                Text(transaction.merchant.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.charcoal)
                    .tracking(0.8)
                    .frame(maxWidth: .infinity)

                HStack {
                    Button("Back", systemImage: "arrow.left", action: { dismiss() })
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)
                    Spacer()
                    Button("Edit", systemImage: "pencil") { }
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)

            // ── Amount ───────────────────────────────────────────────────
            Text(fullINR(transaction.amount))
                .font(.custom("Sora-SemiBold", size: 52))
                .foregroundStyle(AppColors.charcoal)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 14)

            // ── Category chip ────────────────────────────────────────────
            Button { showCategoryPicker = true } label: {
                CategoryChip(
                    category: transaction.category,
                    type: transaction.type
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 28)

            // ── Detail card ──────────────────────────────────────────────
            VStack(spacing: 0) {
                CardRow(label: "DATE") {
                    Text(Self.dateFormatter.string(from: transaction.date))
                        .detailValueStyle()
                }

                CardDivider()

                CardRow(label: "MERCHANT") {
                    HStack(spacing: 4) {
                        Text(transaction.merchant)
                            .detailValueStyle()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.charcoal.opacity(0.25))
                    }
                }

                CardDivider()

                CardRow(label: "EXCLUDE TRANSACTION") {
                    Toggle("", isOn: $isExcluded)
                        .labelsHidden()
                        .tint(AppColors.charcoal)
                }

                CardDivider()

                CardRow(label: "SPLIT TRANSACTION") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal.opacity(0.25))
                }
                .opacity(0.4)
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
                    .stroke(AppColors.charcoal.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
            .padding(.horizontal, 16)

            // ── Account info ─────────────────────────────────────────────
            if !transaction.account.isEmpty || !transaction.bank.isEmpty {
                AccountChip(
                    bank: transaction.bank,
                    account: transaction.account,
                    merchantRaw: transaction.merchantRaw
                )
                .padding(.top, 16)
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 28)

            // ── Delete button ────────────────────────────────────────────
            Button {
                confirmDelete = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                    Text("Delete Transaction")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundStyle(AppColors.charcoal.opacity(0.45))
            }
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
                .ignoresSafeArea()
        )
        .onAppear {
            isExcluded = transaction.excludedFromCalc
        }
        .onDisappear {
            transaction.excludedFromCalc = isExcluded
        }
        .confirmationDialog(
            "Delete this transaction?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(transaction)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(
                currentCategory: transaction.category,
                onSelect: { newCategory in
                    guard newCategory != transaction.category else { return }
                    let merchant = transaction.merchant
                    let descriptor = FetchDescriptor<Transaction>(
                        predicate: #Predicate { $0.merchant == merchant }
                    )
                    let matches = (try? modelContext.fetch(descriptor)) ?? []
                    let otherCount = matches.filter { $0.id != transaction.id }.count
                    if otherCount > 0 {
                        pendingCategoryChange = PendingCategoryChange(
                            newCategory: newCategory,
                            otherCount: otherCount
                        )
                    } else {
                        transaction.category = newCategory
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $pendingCategoryChange) { change in
            BulkCategoryUpdateSheet(
                merchant: transaction.merchant,
                newCategory: change.newCategory,
                otherCount: change.otherCount,
                onUpdateAll: { applyCategory(change.newCategory, toAll: true) },
                onUpdateOne: { applyCategory(change.newCategory, toAll: false) }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    private func applyCategory(_ newCategory: String, toAll: Bool) {
        if toAll {
            let merchant = transaction.merchant
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.merchant == merchant }
            )
            let matches = (try? modelContext.fetch(descriptor)) ?? []
            for t in matches { t.category = newCategory }
        } else {
            transaction.category = newCategory
        }
    }

    private static let inrWholeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₹"
        f.maximumFractionDigits = 0
        return f
    }()

    private static let inrDecimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₹"
        f.maximumFractionDigits = 2
        return f
    }()

    private func fullINR(_ amount: Double) -> String {
        let fmt = amount.truncatingRemainder(dividingBy: 1) == 0
            ? Self.inrWholeFormatter : Self.inrDecimalFormatter
        return fmt.string(from: NSNumber(value: amount)) ?? "₹\(amount)"
    }
}

// MARK: - Category chip

private struct CategoryChip: View {
    let category: String
    let type: String

    private var emoji: String {
        switch category.lowercased() {
        case "groceries":        return "🛒"
        case "food", "dining":   return "🍽️"
        case "shopping":         return "🛍️"
        case "transport", "travel": return "🚗"
        case "utilities":        return "💡"
        case "entertainment":    return "🎬"
        case "health":           return "💊"
        case "rent", "housing":  return "🏠"
        case "education":        return "📚"
        case "salary", "income": return "💰"
        default:                 return type == "credit" ? "💳" : "💸"
        }
    }

    private var iconBg: Color {
        switch category.lowercased() {
        case "groceries":           return Color(red: 0.10, green: 0.62, blue: 0.40)
        case "food", "dining":      return Color(red: 0.90, green: 0.40, blue: 0.20)
        case "shopping":            return Color(red: 0.30, green: 0.40, blue: 0.90)
        case "transport", "travel": return Color(red: 0.20, green: 0.50, blue: 0.85)
        case "utilities":           return Color(red: 0.95, green: 0.70, blue: 0.10)
        default:                    return Color(red: 0.50, green: 0.40, blue: 0.80)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 30, height: 30)
                Text(emoji)
                    .font(.system(size: 14))
            }

            Text(category)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.charcoal.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
                .stroke(AppColors.charcoal.opacity(0.04), lineWidth: 0.5)
        )
    }
}

// MARK: - Card row

private struct CardRow<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.charcoal.opacity(0.45))
                .tracking(0.3)

            Spacer()

            trailing
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

private struct CardDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 18)
    }
}

// MARK: - Text style helper

private extension Text {
    func detailValueStyle() -> some View {
        self
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColors.charcoal)
    }
}

// MARK: - Account chip

private struct AccountChip: View {
    let bank: String
    let account: String
    let merchantRaw: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.15, green: 0.35, blue: 0.80))
                    .frame(width: 36, height: 36)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(account.isEmpty ? bank : "\(bank) - \(account)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.charcoal)
                    .lineLimit(1)

                if !merchantRaw.isEmpty {
                    Text(merchantRaw)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.charcoal.opacity(0.45))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
        )
    }
}

// MARK: - Category picker sheet

private struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentCategory: String
    let onSelect: (String) -> Void

    @State private var searchText = ""
    @State private var filteredCategories: [AppCategory] = CategoryStore.all

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────────────────────
            CategoryPickerHeader(onDismiss: { dismiss() })

            // ── Search bar ───────────────────────────────────────────────
            CategorySearchBar(searchText: $searchText)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

            // ── Section label ────────────────────────────────────────────
            HStack {
                Text("EXPENSE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.charcoal.opacity(0.45))
                    .tracking(0.4)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            // ── Category list ────────────────────────────────────────────
            CategoryListView(
                categories: filteredCategories,
                currentCategory: currentCategory,
                onSelect: { name in
                    onSelect(name)
                    dismiss()
                }
            )
        }
        .background(.white)
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                filteredCategories = CategoryStore.all
            } else {
                let query = newValue.lowercased()
                filteredCategories = CategoryStore.all.filter {
                    $0.name.lowercased().contains(query)
                }
            }
        }
    }
}

// MARK: - Category picker header

private struct CategoryPickerHeader: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Text("MANAGE CATEGORIES")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .tracking(0.6)

            Spacer()

            Button("Close", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.charcoal.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }
}

// MARK: - Category search bar

private struct CategorySearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.charcoal.opacity(0.25))

            TextField("Search", text: $searchText)
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    searchText = ""
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 16))
                .foregroundStyle(AppColors.charcoal.opacity(0.25))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
                .stroke(AppColors.charcoal.opacity(0.04), lineWidth: 0.5)
        )
    }
}

// MARK: - Category list view

private struct CategoryListView: View {
    let categories: [AppCategory]
    let currentCategory: String
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(categories) { cat in
                    CategoryRow(
                        category: cat,
                        isSelected: cat.name == currentCategory,
                        onSelect: onSelect
                    )

                    if cat.id != categories.last?.id {
                        Divider()
                            .padding(.leading, 70)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.charcoal.opacity(0.12).opacity(0.35), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Category row

private struct CategoryRow: View {
    let category: AppCategory
    let isSelected: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Button {
            onSelect(category.name)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(category.color)
                        .frame(width: 38, height: 38)
                    Text(category.emoji)
                        .font(.system(size: 17))
                }

                Text(category.name)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.charcoal)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bulk category update sheet

private struct BulkCategoryUpdateSheet: View {
    @Environment(\.dismiss) private var dismiss
    let merchant: String
    let newCategory: String
    let otherCount: Int
    let onUpdateAll: () -> Void
    let onUpdateOne: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(AppColors.charcoal.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Icon + title
            ZStack {
                Circle()
                    .fill(AppColors.homeBlue.opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: "tag.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.charcoal.opacity(0.7))
            }
            .padding(.bottom, 14)

            Text("Update all \(merchant) transactions?")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Found \(otherCount) other transaction\(otherCount == 1 ? "" : "s") from \(merchant). Move them all to \(newCategory)?")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppColors.charcoal.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 6)

            Spacer(minLength: 24)

            // Action buttons
            VStack(spacing: 10) {
                Button {
                    onUpdateAll()
                    dismiss()
                } label: {
                    Text("Update All \(otherCount + 1) Transactions")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppColors.charcoal)
                        .clipShape(.rect(cornerRadius: 14))
                }

                Button {
                    onUpdateOne()
                    dismiss()
                } label: {
                    Text("Just This Transaction")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.charcoal.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppColors.charcoal.opacity(0.07))
                        .clipShape(.rect(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(.white)
    }
}

// MARK: - Preview

#Preview {
    let txn = Transaction(
        date: .now, amount: 232.58, type: "debit",
        merchant: "Amazon Pay", merchantRaw: "AMAZON PAY",
        category: "Shopping", account: "HDFC ••8760", bank: "HDFC"
    )
    TransactionDetailDrawer(transaction: txn)
        .presentationDetents([.large])
}

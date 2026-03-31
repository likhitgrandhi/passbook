import SwiftUI

// MARK: - Focus fields enum

private enum BudgetField { case income, liabilities, budget }

// MARK: - Create Budget Sheet

struct CreateBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss

    let month: String
    let onSave: (_ income: Double, _ liabilities: Double, _ spendBudget: Double) -> Void

    // Optional initial values for edit mode
    let existingIncome: Double
    let existingLiabilities: Double
    let existingBudget: Double

    private var isEditMode: Bool { existingIncome > 0 || existingLiabilities > 0 || existingBudget > 0 }

    init(
        month: String,
        existingIncome: Double = 0,
        existingLiabilities: Double = 0,
        existingBudget: Double = 0,
        onSave: @escaping (_ income: Double, _ liabilities: Double, _ spendBudget: Double) -> Void
    ) {
        self.month = month
        self.existingIncome = existingIncome
        self.existingLiabilities = existingLiabilities
        self.existingBudget = existingBudget
        self.onSave = onSave
        _income = State(initialValue: existingIncome)
        _liabilities = State(initialValue: existingLiabilities)
        _spendBudget = State(initialValue: existingBudget)
    }

    // Seeded from existing values (or 0 for new)
    @State private var income: Double
    @State private var liabilities: Double
    @State private var spendBudget: Double

    @FocusState private var focused: BudgetField?

    private var disposable: Double { income - liabilities }
    private var savings: Double { disposable - spendBudget }
    private var yearlySavings: Double { savings * 12 }
    private var canSave: Bool { income > 0 && spendBudget > 0 }
    private var isBudgetOverLimit: Bool { disposable > 0 && spendBudget > disposable }

    var body: some View {
        ZStack {
            // ── Tap-to-dismiss layer (behind content) ─────────────────
            AppColors.settingsBg
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { focused = nil }

            // ── Main content ──────────────────────────────────────────
            VStack(spacing: 0) {
                Capsule()
                    .fill(AppColors.charcoal.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 0) {
                        Text("MONTHLY BUDGET")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.charcoal.opacity(0.4))
                            .tracking(0.4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)

                        Text(isEditMode ? "Edit your budget." : "Define your monthly budget.")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.charcoal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)

                        Text("Enter your income and fixed costs. We'll calculate how much you have left to spend and save.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppColors.charcoal.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 36)

                        // ── Income ────────────────────────────────────
                        BudgetAmountDisplay(
                            label: "Monthly income",
                            initialValue: income,
                            isFocused: $focused,
                            field: .income
                        ) { newValue in
                            if newValue != income { income = newValue }
                        }

                        BudgetSeparator(symbol: "−")

                        // ── Fixed liabilities ─────────────────────────
                        BudgetAmountInputCard(
                            label: "Fixed liabilities",
                            hint: "EMIs, loans, rent, subscriptions",
                            warningText: nil,
                            initialValue: liabilities,
                            isFocused: $focused,
                            field: .liabilities
                        ) { newValue in
                            if newValue != liabilities { liabilities = newValue }
                        }

                        BudgetSeparator(symbol: "=")

                        // ── Disposable income ─────────────────────────
                        BudgetCalculatedRow(
                            label: "Disposable income",
                            value: disposable,
                            isActive: income > 0
                        )

                        BudgetSeparator(symbol: "−")

                        // ── Spending budget ───────────────────────────
                        BudgetAmountInputCard(
                            label: "Monthly spending budget",
                            hint: income > 0 && disposable > 0
                                ? "Max available: \(BudgetFormatter.format(disposable))"
                                : "Your discretionary spend target",
                            warningText: isBudgetOverLimit
                                ? "Exceeds disposable income by \(BudgetFormatter.format(spendBudget - disposable))"
                                : nil,
                            initialValue: spendBudget,
                            isFocused: $focused,
                            field: .budget
                        ) { newValue in
                            if newValue != spendBudget { spendBudget = newValue }
                        }

                        BudgetSeparator(symbol: "=")

                        // ── Savings ───────────────────────────────────
                        BudgetSavingsDisplay(
                            savings: savings,
                            yearlySavings: yearlySavings,
                            canCompute: canSave
                        )

                        // ── Save button ───────────────────────────────
                        Button {
                            guard canSave else { return }
                            onSave(income, liabilities, spendBudget)
                            dismiss()
                        } label: {
                            Text("SAVE")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(canSave ? .white : AppColors.charcoal.opacity(0.3))
                                .tracking(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(canSave ? AppColors.charcoal : AppColors.charcoal.opacity(0.07))
                                .clipShape(.rect(cornerRadius: 16))
                        }
                        .disabled(!canSave)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        // ── Keyboard toolbar "Done" button (essential for numberPad) ──
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.charcoal)
            }
        }
    }
}

// MARK: - Plain amount display (income row — no card background)
// Owns its own @State text. Parent only updates when parsed Double changes.

private struct BudgetAmountDisplay: View {
    let label: String
    let initialValue: Double
    var isFocused: FocusState<BudgetField?>.Binding
    let field: BudgetField
    let onValueChange: (Double) -> Void

    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 10) {
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)

            HStack(spacing: 2) {
                Text("₹")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(text.isEmpty ? AppColors.charcoal.opacity(0.22) : AppColors.charcoal)
                TextField("0", text: $text)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.charcoal)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                    .fixedSize()
                    .focused(isFocused, equals: field)
                    .onChange(of: text) { _, newText in
                        let parsed = Double(newText) ?? 0
                        onValueChange(parsed)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .onAppear {
            if initialValue > 0 {
                text = String(Int(initialValue))
            }
        }
    }
}

// MARK: - Card amount input (liabilities & budget rows)
// Owns its own @State text. Parent only updates when parsed Double changes.

private struct BudgetAmountInputCard: View {
    let label: String
    let hint: String
    let warningText: String?
    let initialValue: Double
    var isFocused: FocusState<BudgetField?>.Binding
    let field: BudgetField
    let onValueChange: (Double) -> Void

    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)

            HStack(spacing: 2) {
                Text("₹")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(text.isEmpty ? AppColors.charcoal.opacity(0.22) : AppColors.charcoal)
                TextField("0", text: $text)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(warningText != nil ? Color(red: 0.85, green: 0.18, blue: 0.18) : AppColors.charcoal)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                    .fixedSize()
                    .focused(isFocused, equals: field)
                    .onChange(of: text) { _, newText in
                        let parsed = Double(newText) ?? 0
                        onValueChange(parsed)
                    }
            }
            .padding(.top, 4)

            Divider().frame(width: 120)

            // Hint or warning below the field
            if let warning = warningText {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.85, green: 0.18, blue: 0.18))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            } else {
                Text(hint)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.charcoal.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.charcoal.opacity(0.05))
        )
        .padding(.horizontal, 20)
        .onAppear {
            if initialValue > 0 {
                text = String(Int(initialValue))
            }
        }
    }
}

// MARK: - Calculated row (disposable income — read-only)

private struct BudgetCalculatedRow: View {
    let label: String
    let value: Double
    let isActive: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.charcoal.opacity(0.5))

            Text(isActive ? BudgetFormatter.format(value) : "₹—")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.charcoal.opacity(isActive ? 0.7 : 0.2))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Operator separator

private struct BudgetSeparator: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(size: 18, weight: .light))
            .foregroundStyle(AppColors.charcoal.opacity(0.25))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
    }
}

// MARK: - Savings display (no animations — instant update prevents keystroke lag)

private struct BudgetSavingsDisplay: View {
    let savings: Double
    let yearlySavings: Double
    let canCompute: Bool

    private var isNegative: Bool { savings < 0 }

    var body: some View {
        VStack(spacing: 6) {
            Text("Monthly savings")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)

            Text(canCompute ? BudgetFormatter.format(savings) : "₹0")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    !canCompute ? AppColors.charcoal.opacity(0.2)
                    : isNegative ? Color(red: 0.85, green: 0.18, blue: 0.18)
                    : AppColors.charcoal
                )

            if canCompute && yearlySavings > 0 {
                Text("At this rate, you'll save **\(BudgetFormatter.format(yearlySavings))** per year!")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppColors.charcoal.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Shared formatter (static — allocated once)

enum BudgetFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₹"
        f.maximumFractionDigits = 0
        return f
    }()

    static func format(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
}

#Preview {
    CreateBudgetSheet(month: MonthHelper.current) { _, _, _ in }
}

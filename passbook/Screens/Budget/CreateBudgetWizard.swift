import SwiftUI

// MARK: - Wizard steps

private enum BudgetWizardStep: Int, CaseIterable {
    case income, liabilities, spendBudget, overview
}

// MARK: - Font helper

private func jakarta(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    let name: String
    switch weight {
    case .bold, .heavy, .black:       name = "PlusJakartaSans-Bold"
    case .semibold:                   name = "PlusJakartaSans-SemiBold"
    case .medium:                     name = "PlusJakartaSans-Medium"
    default:                          name = "PlusJakartaSans-Regular"
    }
    return Font.custom(name, size: size)
}

// MARK: - Create Budget Wizard

struct CreateBudgetWizard: View {
    @Environment(\.dismiss) private var dismiss

    let month: String
    let onSave: (_ income: Double, _ liabilities: Double, _ spendBudget: Double) -> Void

    @State private var step: BudgetWizardStep = .income
    @State private var goingForward = true

    @State private var income: Double = 0
    @State private var liabilities: Double = 0
    @State private var spendBudget: Double = 0

    private var disposable: Double { income - liabilities }
    private var savings: Double { disposable - spendBudget }
    private var yearlySavings: Double { savings * 12 }
    private var isBudgetOverLimit: Bool { disposable > 0 && spendBudget > disposable }

    var body: some View {
        ZStack {
            AppColors.wizardBg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        if step == .income {
                            dismiss()
                        } else {
                            goingForward = false
                            withAnimation(.easeInOut(duration: 0.28)) {
                                step = BudgetWizardStep(rawValue: step.rawValue - 1)!
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(AppColors.wizardText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 10)

                ZStack {
                    ForEach(BudgetWizardStep.allCases, id: \.rawValue) { s in
                        if s == step {
                            stepView(for: s)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: goingForward ? .trailing : .leading),
                                        removal:   .move(edge: goingForward ? .leading  : .trailing)
                                    )
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Step views

    @ViewBuilder
    private func stepView(for s: BudgetWizardStep) -> some View {
        switch s {
        case .income:
            WizardInputStep(
                headline: "What's your\nannual income?",
                subHint: "Include employment, rental and investment\nincome before taxes",
                bottomLabel: "Annual income",
                currencyPrefix: "₹",
                value: $income,
                warningText: nil,
                ctaDisabled: income <= 0,
                onContinue: advance
            )
        case .liabilities:
            WizardInputStep(
                headline: "What are your fixed costs?",
                subHint: "EMIs, loans, rent, subscriptions — anything that leaves your account every month.",
                bottomLabel: "Fixed liabilities",
                currencyPrefix: "₹",
                value: $liabilities,
                warningText: nil,
                ctaDisabled: false,
                onContinue: advance
            )
        case .spendBudget:
            WizardInputStep(
                headline: "How much do you want to spend?",
                subHint: "Your discretionary budget for the month.",
                bottomLabel: "Monthly spend budget",
                currencyPrefix: "₹",
                value: $spendBudget,
                warningText: isBudgetOverLimit
                    ? "Exceeds disposable income by \(BudgetFormatter.format(spendBudget - disposable))"
                    : nil,
                ctaDisabled: spendBudget <= 0,
                onContinue: advance
            )
        case .overview:
            overviewStep
        }
    }

    // MARK: - Overview step

    private var overviewStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Here's your budget.")
                    .font(jakarta(28, .bold))
                    .foregroundStyle(AppColors.wizardText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Review everything before saving.")
                    .font(jakarta(14))
                    .foregroundStyle(AppColors.wizardText.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    BudgetCalculatedRow(label: "Monthly income", value: income, isActive: true)
                    BudgetSeparator(symbol: "−")
                    BudgetCalculatedRow(label: "Fixed liabilities", value: liabilities, isActive: true)
                    BudgetSeparator(symbol: "=")
                    BudgetCalculatedRow(label: "Disposable income", value: disposable, isActive: true)
                    BudgetSeparator(symbol: "−")
                    BudgetCalculatedRow(label: "Monthly spending budget", value: spendBudget, isActive: true)
                    BudgetSeparator(symbol: "=")
                    BudgetSavingsDisplay(savings: savings, yearlySavings: yearlySavings, canCompute: true)
                }
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)

            Button {
                onSave(income, liabilities, spendBudget)
                dismiss()
            } label: {
                Text("SAVE BUDGET")
                    .font(jakarta(14, .bold))
                    .foregroundStyle(Color.white)
                    .tracking(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(AppColors.wizardText)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Helpers

    private func advance() {
        goingForward = true
        withAnimation(.easeInOut(duration: 0.28)) {
            step = BudgetWizardStep(rawValue: step.rawValue + 1)!
        }
    }
}

// MARK: - Single input step

private struct WizardInputStep: View {
    let headline: String
    let subHint: String
    let bottomLabel: String
    let currencyPrefix: String
    @Binding var value: Double
    let warningText: String?
    let ctaDisabled: Bool
    let onContinue: () -> Void

    @State private var rawText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(headline)
                    .font(jakarta(54 / 2, .bold))
                    .foregroundStyle(AppColors.wizardText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subHint)
                    .font(jakarta(33 / 2))
                    .foregroundStyle(AppColors.wizardText.opacity(0.76))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)

            Spacer()

            VStack(spacing: 6) {
                Text(formattedValue)
                    .font(jakarta(24, .bold))
                    .foregroundStyle(AppColors.wizardText)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(bottomLabel)
                    .font(jakarta(30 / 2))
                    .foregroundStyle(AppColors.wizardText.opacity(0.46))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }

            if let warningText {
                Label(warningText, systemImage: "exclamationmark.triangle.fill")
                    .font(jakarta(12, .medium))
                    .foregroundStyle(Color(red: 0.85, green: 0.18, blue: 0.18))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 14)
            }

            Spacer()

            TextField("", text: $rawText)
                .keyboardType(.numberPad)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: rawText) { _, newValue in
                    let digitsOnly = newValue.filter(\.isNumber)
                    if digitsOnly != newValue {
                        rawText = digitsOnly
                        return
                    }
                    let parsed = Double(digitsOnly) ?? 0
                    if parsed != value {
                        value = parsed
                    }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer()
                Button {
                    onContinue()
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppColors.wizardText.opacity(ctaDisabled ? 0.28 : 1))
                            .frame(width: 56, height: 56)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                }
                .disabled(ctaDisabled)
                .padding(.trailing, 20)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            if value > 0 {
                rawText = String(Int(value))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }

    private var formattedValue: String {
        let intValue = Int(rawText) ?? 0
        let grouped = NumberFormatter.grouped.string(from: NSNumber(value: intValue)) ?? "0"
        return "\(currencyPrefix)\(grouped)"
    }
}

private extension NumberFormatter {
    static let grouped: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

#Preview {
    CreateBudgetWizard(month: MonthHelper.current) { _, _, _ in }
}

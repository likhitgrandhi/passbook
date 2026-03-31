import ActivityKit
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(TransactionStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var dailyBudgetText: String = ""
    @State private var showingShortcutShare = false
    @State private var showingSetup = false
    @State private var showingBudget = false
    @State private var showingCategories = false
    @State private var exportFileURL: ExportFile? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.settingsBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Header
                    SettingsHeader(onDismiss: { dismiss() })

                    ScrollView {
                        // MARK: - White card
                        VStack(spacing: 0) {
                            // Highlighted row — Setup
                            SettingsHighlightRow(
                                icon: "questionmark.circle",
                                title: "How to Setup",
                                subtitle: "Connect bank SMS for automatic tracking"
                            ) {
                                showingSetup = true
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 12)

                            // Regular rows
                            SettingsMenuRow(
                                icon: "chart.bar",
                                title: "Budget",
                                subtitle: "Daily limit · ₹\(Int(store.dailyBudget)) / day"
                            ) {
                                showingBudget = true
                            }

                            SettingsDivider()

                            SettingsMenuRow(
                                icon: "square.grid.2x2",
                                title: "Categories",
                                subtitle: "Manage spending categories"
                            ) {
                                showingCategories = true
                            }

                            SettingsDivider()

                            SettingsMenuRow(
                                icon: "dot.radiowaves.left.and.right",
                                title: "Live Activities",
                                subtitle: "Dynamic Island notifications"
                            ) {
                                Task { await fireTestLiveActivity(dailyBudget: store.dailyBudget) }
                            }

                            SettingsDivider()

                            SettingsMenuRow(
                                icon: "square.and.arrow.up",
                                title: "Export Data",
                                subtitle: "Download transactions as CSV"
                            ) {
                                exportTransactionsCSV()
                            }
                        }
                        .background(.white)
                        .clipShape(.rect(cornerRadius: 20))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // MARK: - Footer
                        Text("All data stored locally · No accounts required")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.charcoal.opacity(0.3))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 28)
                            .padding(.bottom, 20)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingBudget) {
                BudgetSettingsSheet(dailyBudgetText: $dailyBudgetText, store: store)
            }
            .sheet(isPresented: $showingSetup) {
                SetupSheet(showingShortcutShare: $showingShortcutShare)
            }
            .sheet(isPresented: $showingCategories) {
                NavigationStack {
                    CategoriesView()
                }
            }
            .sheet(isPresented: $showingShortcutShare) {
                if let url = Bundle.main.url(forResource: "LogBankTransaction", withExtension: "shortcut") {
                    ShareSheet(items: [url])
                }
            }
            .sheet(item: $exportFileURL) { file in
                ShareSheet(items: [file.url])
            }
        }
    }

    private func exportTransactionsCSV() {
        var descriptor = FetchDescriptor<Transaction>()
        descriptor.sortBy = [SortDescriptor(\Transaction.date, order: .reverse)]
        guard let transactions = try? modelContext.fetch(descriptor) else { return }

        var csv = "Date,Amount,Type,Merchant,Category,Account,Bank,Excluded,Source\n"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for t in transactions {
            let row = [
                df.string(from: t.date),
                String(t.amount),
                t.type,
                t.merchant.replacingOccurrences(of: ",", with: " "),
                t.category.replacingOccurrences(of: ",", with: " "),
                t.account.replacingOccurrences(of: ",", with: " "),
                t.bank.replacingOccurrences(of: ",", with: " "),
                t.excludedFromCalc ? "yes" : "no",
                t.source
            ].joined(separator: ",")
            csv += row + "\n"
        }

        let filename = "passbook_export_\(Date.now.formatted(.dateTime.year().month().day())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        exportFileURL = ExportFile(url: tempURL)
    }
}

// MARK: - Settings Header

private struct SettingsHeader: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Text("SETTINGS")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .tracking(1.0)

            HStack {
                Button("Back", systemImage: "arrow.left", action: onDismiss)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColors.charcoal)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }
}

// MARK: - Highlighted row (setup CTA)

private struct SettingsHighlightRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppColors.charcoal.opacity(0.8))
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.charcoal)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.charcoal.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.charcoal.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.homeBlue.opacity(0.25))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Standard menu row

private struct SettingsMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColors.charcoal.opacity(0.7))
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.charcoal)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.charcoal.opacity(0.45))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.charcoal.opacity(0.2))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Divider

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 70)
            .padding(.trailing, 20)
    }
}

// MARK: - Budget Sheet

private struct BudgetSettingsSheet: View {
    @Binding var dailyBudgetText: String
    let store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("Set your daily spending limit. Unused budget carries over to the next day.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)

                    HStack {
                        Text("₹")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                        TextField("1500", text: $dailyBudgetText)
                            .font(.system(size: 22, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .onAppear {
                                dailyBudgetText = store.dailyBudget == 0
                                    ? ""
                                    : store.dailyBudget.formatted(.number.precision(.fractionLength(0)))
                            }
                            .onChange(of: dailyBudgetText) { _, newValue in
                                if let parsed = Double(newValue), parsed != store.dailyBudget {
                                    store.dailyBudget = parsed
                                }
                            }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 12))

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Daily Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(red: 0.455, green: 0.741, blue: 0.910))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.black)
    }
}

// MARK: - Setup Sheet

private struct SetupSheet: View {
    @Binding var showingShortcutShare: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Passbook reads your bank SMS automatically using Apple Shortcuts. No manual entry needed.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 8)

                        Button {
                            showingShortcutShare = true
                        } label: {
                            Label("Import Shortcut", systemImage: "square.and.arrow.down")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.455, green: 0.741, blue: 0.910))
                                .clipShape(.rect(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            SetupStep(number: "1", text: "**Shortcuts** → **Automation** → **+** → **Message**")
                            SetupStep(number: "2", text: "**Message Contains** → `₹` → **New Blank Automation**")
                            SetupStep(number: "3", text: "Add the imported **Log Bank Transaction** action")
                            SetupStep(number: "4", text: "Tap **Message** field → choose **Shortcut Input**")
                            SetupStep(number: "5", text: "**Done** → **Run Immediately**")
                            SetupStep(number: "6", text: "Repeat steps 1–5 with keyword `Rs.`")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("How to Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(red: 0.455, green: 0.741, blue: 0.910))
                }
            }
        }
        .presentationBackground(.black)
    }
}

private struct SetupStep: View {
    let number: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.7))
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Test Live Activity

@MainActor
private func fireTestLiveActivity(dailyBudget: Double) async {
    let info = ActivityAuthorizationInfo()
    guard info.areActivitiesEnabled else { return }

    let attributes = TransactionActivityAttributes(merchant: "Swiggy", categoryEmoji: "🍔")
    let todaySpent = dailyBudget * 0.76
    let state = TransactionActivityAttributes.ContentState(
        transactionAmount: 450,
        budgetSpentFraction: 0.76,
        dailyBudgetRemaining: max(0, dailyBudget - todaySpent),
        isOverBudget: false
    )
    let content = ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(30))
    if let activity = try? Activity.request(attributes: attributes, content: content, pushType: nil) {
        Task {
            try? await Task.sleep(for: .seconds(20))
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

// MARK: - Export file wrapper

private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    SettingsView()
        .environment(TransactionStore())
}

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
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Header
                    SettingsHeader(onDismiss: { dismiss() })

                    ScrollView {
                        VStack(spacing: 0) {
                            // MARK: - Main section (Setup / Budget / Categories)
                            SettingsSectionCard {
                                SettingsMenuRow(
                                    icon: "questionmark.circle",
                                    title: "How to Setup",
                                    action: { showingSetup = true }
                                )

                                SettingsDivider()

                                SettingsMenuRow(
                                    icon: "chart.bar",
                                    title: "Budget",
                                    trailingValue: "₹\(Int(store.dailyBudget)) / day",
                                    action: { showingBudget = true }
                                )

                                SettingsDivider()

                                SettingsMenuRow(
                                    icon: "square.grid.2x2",
                                    title: "Categories",
                                    action: { showingCategories = true }
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            // MARK: - App section
                            SettingsSectionLabel(text: "APP")

                            SettingsSectionCard {
                                SettingsMenuRow(
                                    icon: "dot.radiowaves.left.and.right",
                                    title: "Live Activities",
                                    action: {
                                        Task { await fireTestLiveActivity(dailyBudget: store.dailyBudget) }
                                    }
                                )
                            }
                            .padding(.horizontal, 16)

                            // MARK: - Data section
                            SettingsSectionLabel(text: "DATA")

                            SettingsSectionCard {
                                SettingsMenuRow(
                                    icon: "square.and.arrow.up",
                                    title: "Export Data",
                                    action: { exportTransactionsCSV() }
                                )
                            }
                            .padding(.horizontal, 16)
                        }

                        // MARK: - Footer
                        Text("All data stored locally · No accounts required")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
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
            Text("Settings")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            HStack {
                Spacer()
                Button("Close", systemImage: "xmark", action: onDismiss)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}

// MARK: - Section card container

private struct SettingsSectionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Section label

private struct SettingsSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }
}

// MARK: - Standard menu row

private struct SettingsMenuRow: View {
    let icon: String
    let title: String
    var trailingValue: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36)

                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)

                Spacer()

                if let value = trailingValue {
                    Text(value)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
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

import SwiftUI
import SwiftData
import Charts

// ── Computed data models ─────────────────────────────────────────────────────

struct CategorySpendItem: Identifiable {
    let id: String
    let name: String
    let amount: Double
    let fraction: Double  // of total spend (0–1)
    let emoji: String
    let color: Color
}

struct BudgetInsight {
    let icon: String   // SF Symbol
    let title: String
    let body: String
}

struct WeekSpend: Identifiable {
    let id: Int        // 1–4
    let label: String  // "Wk 1"
    let amount: Double
}

// MARK: - Budget View

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allBudgets: [MonthlyBudget]
    @Query(sort: \Transaction.date) private var allTransactions: [Transaction]

    @State private var selectedMonth: String  = MonthHelper.current
    @State private var showingCreateSheet     = false
    @State private var showingEditSheet       = false
    @State private var confirmDelete          = false

    // ── Derived state — only recomputed when inputs change ───────────────────
    @State private var cachedChartData: [DailySpendPoint]        = []
    @State private var cachedTotalSpent: Double                  = 0
    @State private var cachedCategorySpends: [CategorySpendItem] = []
    @State private var cachedAverageDaily: Double                = 0
    @State private var cachedDaysElapsed: Int                    = 1
    @State private var cachedDaysInMonth: Int                    = 30
    @State private var cachedBiggestExpense: Transaction?        = nil
    @State private var cachedBiggestPct: Double                  = 0
    @State private var cachedStatusColor: Color                  = AppColors.charcoal
    @State private var cachedMoneyLeft: Double                   = 0
    @State private var cachedMonthForecast: Double               = 0
    @State private var cachedWeeklySpends: [WeekSpend]           = []
    @State private var cachedActualSavings: Double               = 0
    @State private var cachedTargetSavings: Double               = 0
    @State private var cachedInsights: [BudgetInsight]           = []
    @State private var monthsToShow: [String]                    = MonthHelper.currentYearMonths()
    @State private var topScrollOffset: CGFloat                  = 0

    private var budget: MonthlyBudget? {
        allBudgets.first { $0.month == selectedMonth }
    }

    var body: some View {
        ZStack {
            AppColors.wizardBg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Title ──────────────────────────────────────────────
                    ZStack {
                        Text("Budget")
                            .font(.custom("PlusJakartaSans-Bold", size: 22))
                            .foregroundStyle(AppColors.charcoal)
                            .frame(maxWidth: .infinity, alignment: .center)

                        if budget != nil {
                            HStack {
                                Spacer()
                                Menu {
                                    Button("Edit Budget", systemImage: "pencil") { showingEditSheet = true }
                                    Button("Delete Budget", systemImage: "trash",
                                           role: .destructive) { confirmDelete = true }
                                } label: {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(AppColors.charcoal.opacity(0.4))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    // ── Month pills ────────────────────────────────────────
                    BudgetMonthStrip(months: monthsToShow, selected: $selectedMonth)
                        .padding(.bottom, 20)

                    // ── Hero amount ────────────────────────────────────────
                    BudgetHeroView(amount: cachedTotalSpent, statusColor: cachedStatusColor)
                        .padding(.bottom, 16)

                    // ── Chart ──────────────────────────────────────────────
                    if budget != nil {
                        BudgetChartView(
                            data: cachedChartData,
                            budgetLimit: budget?.spendBudget ?? 0,
                            month: selectedMonth,
                            statusColor: cachedStatusColor
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                    }

                    // ── Cards ──────────────────────────────────────────────
                    if let b = budget {
                        BudgetSections(
                            budget: b,
                            totalSpent: cachedTotalSpent,
                            categorySpends: cachedCategorySpends,
                            averageDaily: cachedAverageDaily,
                            daysElapsed: cachedDaysElapsed,
                            biggestExpense: cachedBiggestExpense,
                            biggestPct: cachedBiggestPct,
                            moneyLeft: cachedMoneyLeft,
                            monthForecast: cachedMonthForecast,
                            weeklySpends: cachedWeeklySpends,
                            actualSavings: cachedActualSavings,
                            targetSavings: cachedTargetSavings,
                            insights: cachedInsights,
                            statusColor: cachedStatusColor
                        )
                    } else {
                        BudgetEmptyPrompt(onCreate: { showingCreateSheet = true })
                            .padding(.horizontal, 16)
                    }

                    Color.clear.frame(height: 40)
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                topScrollOffset = y
            }
            .swipeMonthGesture(months: monthsToShow, selected: $selectedMonth)

            // Top fade — matches the system tab bar blur at the bottom
            LinearGradient(
                colors: [AppColors.wizardBg, AppColors.wizardBg.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .opacity(min(1.0, topScrollOffset / 24.0))
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .top)
        }
        .onAppear { recompute() }
        .onChange(of: selectedMonth) { recompute() }
        .onChange(of: allTransactions) { recompute() }
        .fullScreenCover(isPresented: $showingCreateSheet) {
            CreateBudgetWizard(month: selectedMonth) { income, liabilities, spendBudget in
                modelContext.insert(MonthlyBudget(month: selectedMonth, income: income,
                                                  fixedLiabilities: liabilities, spendBudget: spendBudget))
                recompute()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let b = budget {
                CreateBudgetSheet(month: selectedMonth, existingIncome: b.income,
                                  existingLiabilities: b.fixedLiabilities, existingBudget: b.spendBudget)
                { income, liabilities, spendBudget in
                    b.income = income; b.fixedLiabilities = liabilities; b.spendBudget = spendBudget
                }
                .presentationDetents([.large]).presentationDragIndicator(.hidden).presentationCornerRadius(24)
            }
        }
        .confirmationDialog("Delete this budget?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let b = budget { modelContext.delete(b) } }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Budget for \(MonthHelper.longLabel(selectedMonth)) will be removed.") }
    }

    // MARK: - Recompute

    private func recompute() {
        let cal = Calendar.current
        guard let monthDate = MonthHelper.dateFrom(key: selectedMonth) else { return }
        let year        = cal.component(.year, from: monthDate)
        let monthNum    = cal.component(.month, from: monthDate)
        let isCurrentMonth = selectedMonth == MonthHelper.current
        let daysInMonth = cal.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        let todayDay    = isCurrentMonth ? cal.component(.day, from: .now) : daysInMonth

        let monthTx = allTransactions.filter { t in
            t.type == "debit" && !t.excludedFromCalc &&
            cal.component(.year, from: t.date) == year &&
            cal.component(.month, from: t.date) == monthNum
        }

        // Chart data
        var dailyTotals = [Int: Double]()
        for t in monthTx { dailyTotals[cal.component(.day, from: t.date), default: 0] += t.amount }
        var cum = 0.0
        let chartData = (1...todayDay).map { day -> DailySpendPoint in
            cum += dailyTotals[day] ?? 0
            return DailySpendPoint(id: day, day: day, cumulative: cum)
        }
        let totalSpent = chartData.last?.cumulative ?? 0

        // Category breakdown (top 4)
        var catTotals = [String: Double]()
        for t in monthTx { catTotals[t.category, default: 0] += t.amount }
        let sortedCats = catTotals.sorted { $0.value > $1.value }.prefix(4)
        let categorySpends: [CategorySpendItem] = sortedCats.map { name, amount in
            let cat = AppCategory.defaults.first { $0.name == name }
            return CategorySpendItem(
                id: name, name: name, amount: amount,
                fraction: totalSpent > 0 ? amount / totalSpent : 0,
                emoji: cat?.emoji ?? "💳",
                color: cat?.color ?? AppColors.charcoal.opacity(0.5)
            )
        }

        // Biggest expense
        let biggest = monthTx.max(by: { $0.amount < $1.amount })
        let biggestPct = (totalSpent > 0 && biggest != nil) ? (biggest!.amount / totalSpent) : 0

        // Weekly spends — Week 1: 1-7, Week 2: 8-14, Week 3: 15-21, Week 4: 22-end
        let weekRanges: [(Int, Int)] = [(1,7),(8,14),(15,21),(22,daysInMonth)]
        let weeklySpends: [WeekSpend] = weekRanges.enumerated().map { i, range in
            let total = (range.0...range.1).reduce(0.0) { $0 + (dailyTotals[$1] ?? 0) }
            return WeekSpend(id: i + 1, label: "Wk \(i + 1)", amount: total)
        }

        let elapsed = max(1, todayDay)
        let averageDaily = totalSpent / Double(elapsed)

        // Burn rate stats
        let moneyLeft = (allBudgets.first { $0.month == selectedMonth }?.spendBudget ?? 0) - totalSpent
        let monthForecast = averageDaily * Double(daysInMonth)

        // Savings
        let actualSavings: Double
        let targetSavings: Double
        if let b = allBudgets.first(where: { $0.month == selectedMonth }) {
            actualSavings = b.income - b.fixedLiabilities - totalSpent
            targetSavings = b.income - b.fixedLiabilities - b.spendBudget
        } else {
            actualSavings = 0; targetSavings = 0
        }

        // Insights
        var insights: [BudgetInsight] = []
        if let topCat = categorySpends.first {
            let pct = Int((topCat.fraction * 100).rounded())
            insights.append(BudgetInsight(
                icon: "exclamationmark.triangle.fill",
                title: "Cut back on \(topCat.name)",
                body: "It accounts for \(pct)% of your spend this month."
            ))
        }
        if let b = allBudgets.first(where: { $0.month == selectedMonth }), b.spendBudget > 0 {
            let overshoot = monthForecast - b.spendBudget
            if overshoot > 0 {
                insights.append(BudgetInsight(
                    icon: "flame.fill",
                    title: "You're burning too fast",
                    body: "At \(compactINR(averageDaily))/day, you'll overshoot by \(compactINR(overshoot)) by month end."
                ))
            } else {
                insights.append(BudgetInsight(
                    icon: "checkmark.seal.fill",
                    title: "You're on track",
                    body: "At \(compactINR(averageDaily))/day, you'll stay \(compactINR(abs(overshoot))) under budget."
                ))
            }
        }
        if targetSavings > 0 {
            let diff = actualSavings - targetSavings
            if diff >= 0 {
                insights.append(BudgetInsight(
                    icon: "banknote.fill",
                    title: "Savings on target",
                    body: "You've preserved \(compactINR(actualSavings)) this month. Target was \(compactINR(targetSavings))."
                ))
            } else {
                insights.append(BudgetInsight(
                    icon: "banknote.fill",
                    title: "Savings lagging",
                    body: "You've preserved \(compactINR(max(0, actualSavings))) so far. Target was \(compactINR(targetSavings))."
                ))
            }
        }

        // Assign
        cachedChartData       = chartData
        cachedTotalSpent      = totalSpent
        cachedDaysElapsed     = elapsed
        cachedDaysInMonth     = daysInMonth
        cachedAverageDaily    = averageDaily
        cachedCategorySpends  = categorySpends
        cachedBiggestExpense  = biggest
        cachedBiggestPct      = biggestPct
        cachedMoneyLeft       = moneyLeft
        cachedMonthForecast   = monthForecast
        cachedWeeklySpends    = weeklySpends
        cachedActualSavings   = actualSavings
        cachedTargetSavings   = targetSavings
        cachedInsights        = insights

        if let b = allBudgets.first(where: { $0.month == selectedMonth }) {
            cachedStatusColor = totalSpent > b.spendBudget
                ? Color(red: 0.72, green: 0.11, blue: 0.11)
                : Color(red: 0.10, green: 0.58, blue: 0.32)
        } else {
            cachedStatusColor = AppColors.charcoal
        }
    }
}

// MARK: - Swipe month gesture

private extension View {
    func swipeMonthGesture(months: [String], selected: Binding<String>) -> some View {
        self.gesture(
            DragGesture(minimumDistance: 30).onEnded { v in
                let dx = v.translation.width; let dy = abs(v.translation.height)
                guard abs(dx) > dy, abs(dx) > 30 else { return }
                guard let idx = months.firstIndex(of: selected.wrappedValue) else { return }
                let newIdx = dx < 0 ? idx + 1 : idx - 1
                guard months.indices.contains(newIdx) else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    selected.wrappedValue = months[newIdx]
                }
            }
        )
    }
}

// MARK: - Month pill strip

private struct BudgetMonthStrip: View {
    let months: [String]
    @Binding var selected: String

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(months, id: \.self) { month in
                        BudgetMonthPill(month: month, isSelected: selected == month) {
                            selected = month
                        }
                    }
                }
                .padding(.horizontal, 20)
                .frame(minWidth: geo.size.width, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: 38)
    }
}

private struct BudgetMonthPill: View {
    let month: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(MonthHelper.shortLabel(month))
                .font(.custom(isSelected ? "PlusJakartaSans-Bold" : "PlusJakartaSans-Medium", size: 14))
                .foregroundStyle(AppColors.charcoal)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.white : Color(red: 0.976, green: 0.976, blue: 0.976))
                        .shadow(color: isSelected ? .black.opacity(0.08) : .clear, radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hero amount

private struct BudgetHeroView: View {
    let amount: Double
    let statusColor: Color

    private func fmt(_ v: Double) -> String {
        let x: Double; let suffix: String
        if v >= 10_000_000    { x = v / 10_000_000; suffix = "Cr" }
        else if v >= 100_000  { x = v / 100_000;    suffix = "L"  }
        else if v >= 1_000    { x = v / 1_000;      suffix = "K"  }
        else                   { x = v;              suffix = ""   }
        let rounded = (x * 10).rounded() / 10
        let num = rounded == rounded.rounded(.towardZero)
            ? Int(rounded).formatted()
            : rounded.formatted(.number.precision(.fractionLength(1)))
        return "₹\(num)\(suffix)"
    }

    var body: some View {
        Text(fmt(amount))
            .font(.custom("Sora-SemiBold", size: 90))
            .tracking(-3.6)
            .monospacedDigit()
            .foregroundStyle(statusColor)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
    }
}

// MARK: - Line chart

private struct BudgetChartView: View {
    let data: [DailySpendPoint]
    let budgetLimit: Double
    let month: String
    let statusColor: Color

    private var todayPoint: DailySpendPoint? { data.last }
    private var daysInMonth: Int {
        guard let d = MonthHelper.dateFrom(key: month) else { return 31 }
        return Calendar.current.range(of: .day, in: .month, for: d)?.count ?? 31
    }
    private var yMax: Double {
        let peak = max(budgetLimit, data.last?.cumulative ?? 0)
        return max(peak * 1.35, 500)
    }

    var body: some View {
        Chart {
            ForEach(data) { pt in
                AreaMark(x: .value("Day", pt.day), y: .value("Amt", pt.cumulative))
                    .foregroundStyle(AppColors.charcoal.opacity(0.06))
                    .interpolationMethod(.linear)
                LineMark(x: .value("Day", pt.day), y: .value("Amt", pt.cumulative))
                    .foregroundStyle(AppColors.charcoal)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.linear)
            }
            if budgetLimit > 0 {
                RuleMark(y: .value("Budget", budgetLimit))
                    .foregroundStyle(statusColor.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .topTrailing, spacing: 2) {
                        Text(BudgetFormatter.format(budgetLimit))
                            .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(statusColor.opacity(0.85))
                            .clipShape(.rect(cornerRadius: 4))
                    }
            }
            if let today = todayPoint {
                PointMark(x: .value("Day", today.day), y: .value("Amt", today.cumulative))
                    .symbolSize(60)
                    .foregroundStyle(AppColors.charcoal)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 7)) { v in
                AxisValueLabel {
                    if let d = v.as(Int.self) {
                        Text(String(format: "%02d", d))
                            .font(.custom("PlusJakartaSans-Regular", size: 9))
                            .foregroundStyle(AppColors.charcoal.opacity(0.4))
                    }
                }
                AxisGridLine().foregroundStyle(Color.clear)
                AxisTick().foregroundStyle(Color.clear)
            }
        }
        .chartYAxis(.hidden)
        .chartXScale(domain: 1...daysInMonth)
        .chartYScale(domain: 0...yMax)
        .frame(height: 160)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Section cards container

private struct BudgetSections: View {
    let budget: MonthlyBudget
    let totalSpent: Double
    let categorySpends: [CategorySpendItem]
    let averageDaily: Double
    let daysElapsed: Int
    let biggestExpense: Transaction?
    let biggestPct: Double
    let moneyLeft: Double
    let monthForecast: Double
    let weeklySpends: [WeekSpend]
    let actualSavings: Double
    let targetSavings: Double
    let insights: [BudgetInsight]
    let statusColor: Color

    private let errorColor  = Color(red: 0.72, green: 0.11, blue: 0.11)
    private let successColor = Color(red: 0.10, green: 0.58, blue: 0.32)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            BudgetSectionCard(heading: "How fast are you spending right now?") {
                BurnRateCard(
                    averageDaily: averageDaily,
                    moneyLeft: moneyLeft,
                    monthForecast: monthForecast,
                    spendBudget: budget.spendBudget,
                    errorColor: errorColor,
                    successColor: successColor
                )
            }

            BudgetSectionCard(heading: "Where is the money actually going?") {
                CategoryBreakdownCard(
                    categorySpends: categorySpends,
                    spendBudget: budget.spendBudget
                )
            }

            BudgetSectionCard(heading: "What was your biggest purchase this month?") {
                SpotlightCard(
                    transaction: biggestExpense,
                    biggestPct: biggestPct
                )
            }

            BudgetSectionCard(heading: "Which week did you spend the most?") {
                WeekByWeekCard(
                    weeklySpends: weeklySpends,
                    errorColor: errorColor,
                    successColor: successColor
                )
            }

            BudgetSectionCard(heading: "How close are you to what you're building towards?") {
                SavingsMomentumCard(
                    actualSavings: actualSavings,
                    targetSavings: targetSavings,
                    errorColor: errorColor,
                    successColor: successColor
                )
            }

            if !insights.isEmpty {
                BudgetSectionCard(heading: "What should next month look different?") {
                    LookingAheadCard(insights: insights)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Section card wrapper

private struct BudgetSectionCard<Content: View>: View {
    let heading: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.custom("PlusJakartaSans-Bold", size: 18))
                .foregroundStyle(AppColors.charcoal)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
        }
    }
}

// MARK: - Card 2: Burn Rate

private struct BurnRateCard: View {
    let averageDaily: Double
    let moneyLeft: Double
    let monthForecast: Double
    let spendBudget: Double
    let errorColor: Color
    let successColor: Color

    private var isOverBudget: Bool { moneyLeft < 0 }
    private var forecastOver: Bool { monthForecast > spendBudget }

    var body: some View {
        VStack(spacing: 0) {
            burnRow(
                label: "Daily burn",
                value: compactINR(averageDaily) + "/day",
                valueColor: AppColors.charcoal
            )
            cardDivider
            burnRow(
                label: "Money left",
                value: isOverBudget ? "-\(compactINR(abs(moneyLeft)))" : compactINR(moneyLeft),
                valueColor: isOverBudget ? errorColor : successColor
            )
            cardDivider
            burnRow(
                label: "Month-end forecast",
                value: forecastOver
                    ? "Over by \(compactINR(monthForecast - spendBudget))"
                    : "On track",
                valueColor: forecastOver ? errorColor : successColor
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func burnRow(label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(AppColors.charcoal.opacity(0.5))
            Spacer()
            Text(value)
                .font(.custom("PlusJakartaSans-Bold", size: 15))
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 18)
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(AppColors.charcoal.opacity(0.07))
            .frame(height: 0.5)
    }
}

// MARK: - Card 3: Category Breakdown

private struct CategoryBreakdownCard: View {
    let categorySpends: [CategorySpendItem]
    let spendBudget: Double

    var body: some View {
        if categorySpends.isEmpty {
            Text("No transactions yet this month")
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(AppColors.charcoal.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(16)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(categorySpends.enumerated()), id: \.element.id) { i, item in
                    CategoryBreakdownRow(item: item, spendBudget: spendBudget)
                    if i < categorySpends.count - 1 {
                        Rectangle()
                            .fill(AppColors.charcoal.opacity(0.07))
                            .frame(height: 0.5)
                            .padding(.leading, 56)
                    }
                }
            }
        }
    }
}

private struct CategoryBreakdownRow: View {
    let item: CategorySpendItem
    let spendBudget: Double

    private var barFraction: Double {
        spendBudget > 0 ? min(1.0, item.amount / spendBudget) : item.fraction
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Square pastel avatar
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(item.color.opacity(0.35))
                    .frame(width: 42, height: 42)
                Text(item.emoji).font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(item.name)
                        .font(.custom("PlusJakartaSans-Medium", size: 14))
                        .foregroundStyle(AppColors.charcoal)
                    Spacer()
                    Text(BudgetFormatter.format(item.amount))
                        .font(.custom("PlusJakartaSans-Bold", size: 14))
                        .foregroundStyle(AppColors.charcoal)
                }
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.charcoal.opacity(0.08))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(item.color.opacity(0.6))
                            .frame(width: geo.size.width * barFraction, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Card 4: Spotlight

private struct SpotlightCard: View {
    let transaction: Transaction?
    let biggestPct: Double

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM"; return f
    }()

    var body: some View {
        if let t = transaction {
            HStack(alignment: .center, spacing: 14) {
                // Square pastel trophy avatar
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 1.0, green: 0.82, blue: 0.40).opacity(0.45))
                        .frame(width: 42, height: 42)
                    Text("🏆").font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(t.merchant)
                        .font(.custom("PlusJakartaSans-Bold", size: 16))
                        .foregroundStyle(AppColors.charcoal)
                    Text("\(t.category) · \(Self.df.string(from: t.date))")
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundStyle(AppColors.charcoal.opacity(0.45))
                    if biggestPct > 0 {
                        Text(String(format: "%.1f%% of total spend", biggestPct * 100))
                            .font(.custom("PlusJakartaSans-Regular", size: 11))
                            .foregroundStyle(AppColors.charcoal.opacity(0.35))
                    }
                }

                Spacer()

                Text(compactINR(t.amount))
                    .font(.custom("PlusJakartaSans-Bold", size: 18))
                    .foregroundStyle(AppColors.charcoal)
            }
            .padding(20)
        } else {
            Text("No transactions yet")
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(AppColors.charcoal.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(16)
        }
    }
}

// MARK: - Card 5: Week by Week

private struct WeekByWeekCard: View {
    let weeklySpends: [WeekSpend]
    let errorColor: Color
    let successColor: Color

    private var maxWeek: WeekSpend? { weeklySpends.max(by: { $0.amount < $1.amount }) }
    private var minWeek: WeekSpend? {
        weeklySpends.filter { $0.amount > 0 }.min(by: { $0.amount < $1.amount })
    }

    var body: some View {
        Chart(weeklySpends) { week in
            BarMark(
                x: .value("Week", week.label),
                y: .value("Amount", week.amount)
            )
            .foregroundStyle(barColor(for: week))
            .cornerRadius(4)
            .annotation(position: .top, spacing: 4) {
                if week.amount > 0 {
                    Text(compactINR(week.amount))
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .foregroundStyle(AppColors.charcoal.opacity(0.6))
                }
            }
        }
        .chartXAxis {
            AxisMarks { v in
                AxisValueLabel {
                    if let l = v.as(String.self) {
                        Text(l)
                            .font(.custom("PlusJakartaSans-Regular", size: 11))
                            .foregroundStyle(AppColors.charcoal.opacity(0.5))
                    }
                }
                AxisGridLine().foregroundStyle(Color.clear)
                AxisTick().foregroundStyle(Color.clear)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 150)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func barColor(for week: WeekSpend) -> Color {
        if week.id == maxWeek?.id { return errorColor }
        if week.id == minWeek?.id { return successColor }
        return AppColors.charcoal.opacity(0.2)
    }
}

// MARK: - Card 6: Savings Momentum

private struct SavingsMomentumCard: View {
    let actualSavings: Double
    let targetSavings: Double
    let errorColor: Color
    let successColor: Color

    private var isOnTarget: Bool { actualSavings >= targetSavings }

    var body: some View {
        VStack(spacing: 0) {
            savingsRow(label: "Target savings", value: compactINR(max(0, targetSavings)), color: AppColors.charcoal, showBadge: false)
            Rectangle().fill(AppColors.charcoal.opacity(0.07)).frame(height: 0.5)
            savingsRow(
                label: "Actual saved",
                value: compactINR(max(0, actualSavings)),
                color: isOnTarget ? successColor : errorColor,
                showBadge: true
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func savingsRow(label: String, value: String, color: Color, showBadge: Bool) -> some View {
        HStack {
            Text(label)
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(AppColors.charcoal.opacity(0.5))
            Spacer()
            HStack(spacing: 6) {
                Text(value)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                    .foregroundStyle(color)
                if showBadge {
                    Image(systemName: isOnTarget ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(isOnTarget ? successColor : errorColor)
                }
            }
        }
        .padding(.vertical, 18)
    }
}

// MARK: - Card 7: Looking Ahead

private struct LookingAheadCard: View {
    let insights: [BudgetInsight]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(insights.enumerated()), id: \.offset) { i, insight in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColors.charcoal.opacity(0.07))
                            .frame(width: 40, height: 40)
                        Image(systemName: insight.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColors.charcoal.opacity(0.55))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.custom("PlusJakartaSans-Bold", size: 14))
                            .foregroundStyle(AppColors.charcoal)
                        Text(insight.body)
                            .font(.custom("PlusJakartaSans-Regular", size: 12))
                            .foregroundStyle(AppColors.charcoal.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                if i < insights.count - 1 {
                    Rectangle()
                        .fill(AppColors.charcoal.opacity(0.07))
                        .frame(height: 0.5)
                }
            }
        }
    }
}

// MARK: - Empty state

private struct BudgetEmptyPrompt: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppColors.charcoal.opacity(0.2))
                .padding(.top, 32)

            Text("No budget set for this month")
                .font(.custom("PlusJakartaSans-Bold", size: 17))
                .foregroundStyle(AppColors.charcoal)

            Text("Set your income and spending target\nto start tracking your month.")
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(AppColors.charcoal.opacity(0.45))
                .multilineTextAlignment(.center)

            Button(action: onCreate) {
                Text("CREATE BUDGET")
                    .font(.custom("PlusJakartaSans-Bold", size: 14))
                    .foregroundStyle(.white).tracking(0.6)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(AppColors.charcoal)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 24).padding(.bottom, 32).padding(.top, 4)
        }
    }
}

// MARK: - Chart data

struct DailySpendPoint: Identifiable {
    let id: Int; let day: Int; let cumulative: Double
}

// MARK: - Month helper

enum MonthHelper {
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f
    }()
    private static let monthAbbr: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()

    static var current: String { keyFormatter.string(from: .now) }

    static func currentYearMonths() -> [String] {
        let cal = Calendar.current; let now = Date.now
        let cm = cal.component(.month, from: now); let cy = cal.component(.year, from: now)
        return (1...cm).compactMap { m in
            var c = DateComponents(); c.year = cy; c.month = m; c.day = 1
            guard let d = cal.date(from: c) else { return nil }
            return keyFormatter.string(from: d)
        }
    }

    static func key(for date: Date) -> String { keyFormatter.string(from: date) }
    static func dateFrom(key: String) -> Date? { keyFormatter.date(from: key) }

    static func shortLabel(_ key: String) -> String {
        guard let d = keyFormatter.date(from: key) else { return key }
        let y = Calendar.current.component(.year, from: d) % 100
        return "\(monthAbbr.string(from: d)) '\(String(format: "%02d", y))"
    }

    static func longLabel(_ key: String) -> String {
        guard let d = keyFormatter.date(from: key) else { return key }
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: d)
    }
}


#Preview {
    BudgetView()
        .environment(TransactionStore())
        .modelContainer(SharedModelContainer.shared)
}

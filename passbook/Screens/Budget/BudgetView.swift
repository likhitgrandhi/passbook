import SwiftUI
import SwiftData
import Charts

// ── Card position constants — identical to home page ────────────────────────
private let kBudgetPeekFraction: CGFloat   = 0.56
private let kBudgetExpandFraction: CGFloat = 0.22

// ── Computed data models ─────────────────────────────────────────────────────

struct CategorySpendItem: Identifiable {
    let id: String      // category name
    let name: String
    let amount: Double
    let fraction: Double  // of total spend (0–1)
    let emoji: String
    let color: Color
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

    // ── Card drag state — identical to home page ─────────────────────────────
    @State private var cardFraction: CGFloat   = kBudgetPeekFraction
    @State private var dragOffset: CGFloat     = 0
    @State private var listScrollOffset: CGFloat = 0
    @State private var isScrollEnabled         = false

    // ── All derived state — only recomputed when inputs change ───────────────
    @State private var cachedChartData: [DailySpendPoint]        = []
    @State private var cachedTotalSpent: Double                  = 0
    @State private var cachedCategorySpends: [CategorySpendItem] = []
    @State private var cachedAverageDaily: Double                = 0
    @State private var cachedDaysElapsed: Int                    = 1
    @State private var cachedBiggestExpense: Transaction?        = nil
    @State private var cachedStatusColor: Color                  = AppColors.charcoal
    // Cached once at init — currentYearMonths() does Calendar + DateFormatter
    // work and never changes mid-session (only changes at month boundary).
    @State private var monthsToShow: [String]                    = MonthHelper.currentYearMonths()

    private var budget: MonthlyBudget? {
        allBudgets.first { $0.month == selectedMonth }
    }

    // ── Snap card — identical logic to home page ──────────────────────────────
    private func snapCard(translationY: CGFloat, predictedY: CGFloat, screenH: CGFloat) {
        let peekY    = screenH * kBudgetPeekFraction
        let expandY  = screenH * kBudgetExpandFraction
        let currentY = screenH * cardFraction + translationY
        let midY     = (peekY + expandY) / 2
        let goExpand = currentY < midY || (predictedY - translationY) < -200

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            cardFraction = goExpand ? kBudgetExpandFraction : kBudgetPeekFraction
            dragOffset   = 0
        } completion: {
            isScrollEnabled = goExpand
        }
    }

    var body: some View {
        Group {
            if budget == nil {
                noBudgetLayout
            } else {
                budgetLayout
            }
        }
        // Lifecycle — on BudgetView, not per-layout, so recompute() fires
        // regardless of which layout is currently showing.
        .onAppear { recompute() }
        .onChange(of: selectedMonth) { recompute() }
        .onChange(of: allTransactions) { recompute() }
        // Sheets — also at this level so they work from both layouts
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

    // MARK: - No budget layout (fixed, non-collapsable)
    // Card sits exactly 24pt below the hero amount — no drag, fully open.

    private var noBudgetLayout: some View {
        ZStack(alignment: .top) {
            cachedStatusColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Colored header section
                BudgetTopContent(
                    monthsToShow: monthsToShow,
                    selectedMonth: $selectedMonth,
                    totalSpent: cachedTotalSpent,
                    chartData: [],
                    budgetLimit: 0,
                    showChart: false
                )

                // 24pt gap between hero bottom and card top
                Spacer().frame(height: 24)

                // White card — fixed open, fills remaining space
                VStack(spacing: 0) {
                    BudgetEmptyPrompt(onCreate: { showingCreateSheet = true })
                    Color.white.frame(height: 400)
                }
                .background(.white)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0, topTrailingRadius: 24,
                        style: .continuous
                    )
                )
                .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: -4)
            }
            .swipeMonthGesture(months: monthsToShow, selected: $selectedMonth)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Budget exists layout (draggable card)

    private var budgetLayout: some View {
        GeometryReader { geo in
            let screenH   = geo.size.height
            let peekY     = screenH * kBudgetPeekFraction
            let expandY   = screenH * kBudgetExpandFraction
            let cardY     = max(expandY, min(peekY, screenH * cardFraction + dragOffset))
            let progress  = (cardY - expandY) / (peekY - expandY)
            let topRadius: CGFloat = 22 + (1 - progress) * 22

            ZStack(alignment: .top) {
                cachedStatusColor.ignoresSafeArea()

                // Colored top content — clipped at cardY
                BudgetTopContent(
                    monthsToShow: monthsToShow,
                    selectedMonth: $selectedMonth,
                    totalSpent: cachedTotalSpent,
                    chartData: cachedChartData,
                    budgetLimit: budget?.spendBudget ?? 0,
                    showChart: true
                )
                .frame(height: cardY, alignment: .top)
                .clipped()
                .opacity(progress < 0.01 ? 0 : 1)

                // Draggable detail card
                VStack(spacing: 0) {
                    BudgetDetailCard(
                        budget: budget,
                        totalSpent: cachedTotalSpent,
                        categorySpends: cachedCategorySpends,
                        averageDaily: cachedAverageDaily,
                        daysElapsed: cachedDaysElapsed,
                        biggestExpense: cachedBiggestExpense,
                        isExpanded: isScrollEnabled,
                        scrollOffset: $listScrollOffset,
                        onCreateBudget: { showingCreateSheet = true },
                        onEdit: { showingEditSheet = true },
                        onDelete: { confirmDelete = true }
                    )
                    Color.white.frame(height: 400)
                }
                .offset(y: cardY)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: topRadius, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0, topTrailingRadius: topRadius,
                        style: .continuous
                    )
                )
                .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: -4)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { v in
                            isScrollEnabled = false
                            let dy = v.translation.height
                            if dy > 0 || listScrollOffset >= -1 { dragOffset = dy }
                        }
                        .onEnded { v in
                            let dy = v.translation.height
                            if dy > 0 || listScrollOffset >= -1 {
                                snapCard(translationY: v.translation.height,
                                         predictedY: v.predictedEndTranslation.height,
                                         screenH: screenH)
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
            .swipeMonthGesture(months: monthsToShow, selected: $selectedMonth)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // ── Recompute all derived state — called only when inputs change ──────────
    private func recompute() {
        let cal = Calendar.current
        guard let monthDate = MonthHelper.dateFrom(key: selectedMonth) else { return }
        let year     = cal.component(.year, from: monthDate)
        let monthNum = cal.component(.month, from: monthDate)
        let isCurrentMonth = selectedMonth == MonthHelper.current
        let daysInMonth = cal.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        let todayDay = isCurrentMonth ? cal.component(.day, from: .now) : daysInMonth

        // Filter month transactions
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

        // Category breakdown (top 5 by amount)
        var catTotals = [String: Double]()
        for t in monthTx { catTotals[t.category, default: 0] += t.amount }
        let sorted = catTotals.sorted { $0.value > $1.value }.prefix(4)
        let categorySpends: [CategorySpendItem] = sorted.map { name, amount in
            let cat = AppCategory.defaults.first { $0.name == name }
            return CategorySpendItem(
                id: name, name: name, amount: amount,
                fraction: totalSpent > 0 ? amount / totalSpent : 0,
                emoji: cat?.emoji ?? "💳",
                color: cat?.color ?? AppColors.charcoal.opacity(0.5)
            )
        }

        // Biggest single transaction
        let biggest = monthTx.max(by: { $0.amount < $1.amount })

        // Average daily
        let elapsed = max(1, todayDay)

        // Assign directly — recompute() is only called when data actually changes.
        // The old equality checks (e.g. map(\.cumulative)) were O(n) and more
        // expensive than the assignments they were guarding.
        cachedChartData       = chartData
        cachedTotalSpent      = totalSpent
        cachedDaysElapsed     = elapsed
        cachedAverageDaily    = totalSpent / Double(elapsed)
        cachedCategorySpends  = categorySpends
        cachedBiggestExpense  = biggest

        // Status color cached here so body never computes it during drag
        if let b = allBudgets.first(where: { $0.month == selectedMonth }) {
            cachedStatusColor = totalSpent > b.spendBudget
                ? Color(red: 0.72, green: 0.11, blue: 0.11)
                : Color(red: 0.10, green: 0.58, blue: 0.32)
        } else {
            cachedStatusColor = AppColors.charcoal
        }
    }
}

// MARK: - Shared top content (title + pills + hero + optional chart)

private struct BudgetTopContent: View {
    let monthsToShow: [String]
    @Binding var selectedMonth: String
    let totalSpent: Double
    let chartData: [DailySpendPoint]
    let budgetLimit: Double
    let showChart: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BUDGETING")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .tracking(1.0)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 14)

            BudgetMonthStrip(months: monthsToShow, selected: $selectedMonth)
                .padding(.bottom, 16)

            BudgetHeroView(
                headline: MonthHelper.longLabel(selectedMonth),
                amount: totalSpent
            )
            .fixedSize(horizontal: false, vertical: true)

            if showChart {
                BudgetChartView(
                    data: chartData,
                    budgetLimit: budgetLimit,
                    month: selectedMonth
                )
                Spacer(minLength: 0) // only expands in budgetLayout where .frame(height:) constrains it
            }
        }
    }
}

// MARK: - Swipe month gesture (extracted to avoid duplication)

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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(months, id: \.self) { month in
                    BudgetMonthPill(month: month, isSelected: selected == month) {
                        selected = month
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }
}

private struct BudgetMonthPill: View {
    let month: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(MonthHelper.shortLabel(month))
                .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? AppColors.charcoal : .white.opacity(0.7))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white)
                        : nil
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hero amount view (all white — on colored bg)

private struct BudgetHeroView: View {
    let headline: String
    let amount: Double

    private func fmt(_ v: Double) -> String {
        let x: Double
        let suffix: String
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(headline)
                    .font(.caption.weight(.medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.75))

            Text(fmt(amount))
                .font(.custom("Sora-SemiBold", size: 90))
                .tracking(-3.6)
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - Line chart (white on colored bg)

private struct BudgetChartView: View {
    let data: [DailySpendPoint]
    let budgetLimit: Double
    let month: String

    private var todayDay: Int {
        month == MonthHelper.current
            ? Calendar.current.component(.day, from: .now)
            : (data.last?.day ?? 0)
    }
    private var todayPoint: DailySpendPoint? { data.last }
    private var daysInMonth: Int {
        guard let d = MonthHelper.dateFrom(key: month) else { return 31 }
        return Calendar.current.range(of: .day, in: .month, for: d)?.count ?? 31
    }
    private var yMax: Double {
        max(budgetLimit * 1.25, (data.last?.cumulative ?? 1) * 1.2, 1)
    }

    var body: some View {
        Chart {
            ForEach(data) { pt in
                LineMark(x: .value("Day", pt.day), y: .value("Amt", pt.cumulative))
                    .foregroundStyle(.white)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
            }
            if budgetLimit > 0 {
                RuleMark(y: .value("Budget", budgetLimit))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .topLeading, spacing: 2) {
                        Text(BudgetFormatter.format(budgetLimit))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.charcoal.opacity(0.7))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.white)
                            .clipShape(.rect(cornerRadius: 4))
                    }
            }
            if let today = todayPoint {
                PointMark(x: .value("Day", today.day), y: .value("Amt", today.cumulative))
                    .symbolSize(50).foregroundStyle(.white)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 7)) { v in
                AxisValueLabel {
                    if let d = v.as(Int.self) {
                        Text(String(format: "%02d", d))
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                AxisGridLine().foregroundStyle(Color.clear)
                AxisTick().foregroundStyle(Color.clear)
            }
        }
        .chartYAxis(.hidden)
        .chartXScale(domain: 1...daysInMonth)
        .chartYScale(domain: 0...yMax)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Detail card (Flighty-style scrollable sections)

private struct BudgetDetailCard: View {
    let budget: MonthlyBudget?
    let totalSpent: Double
    let categorySpends: [CategorySpendItem]
    let averageDaily: Double
    let daysElapsed: Int
    let biggestExpense: Transaction?
    let isExpanded: Bool
    @Binding var scrollOffset: CGFloat
    let onCreateBudget: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Drag handle — identical to home page ───────────────────────
            Capsule()
                .fill(AppColors.charcoal.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 10).padding(.bottom, 14)

            // ── Header row with settings gear ─────────────────────────────
            HStack {
                Text("Budget for month")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColors.charcoal)
                Spacer()
                if budget != nil {
                    Menu {
                        Button("Edit Budget", systemImage: "pencil", action: onEdit)
                        Button("Delete Budget", systemImage: "trash",
                               role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppColors.charcoal.opacity(0.45))
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 12)

            // ── Scrollable content ─────────────────────────────────────────
            if let b = budget {
                BudgetScrollContent(
                    budget: b,
                    totalSpent: totalSpent,
                    categorySpends: categorySpends,
                    averageDaily: averageDaily,
                    daysElapsed: daysElapsed,
                    biggestExpense: biggestExpense,
                    isExpanded: isExpanded,
                    scrollOffset: $scrollOffset
                )
            } else {
                BudgetEmptyPrompt(onCreate: onCreateBudget)
            }
        }
        .background(.white)
    }
}

// MARK: - Scroll content (3 Flighty-style sections)

private struct BudgetScrollContent: View {
    let budget: MonthlyBudget
    let totalSpent: Double
    let categorySpends: [CategorySpendItem]
    let averageDaily: Double
    let daysElapsed: Int
    let biggestExpense: Transaction?
    let isExpanded: Bool
    @Binding var scrollOffset: CGFloat

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                // ── Section 1: Category Spend ──────────────────────────────
                CategorySpendSection(
                    categorySpends: categorySpends,
                    totalSpent: totalSpent,
                    spendBudget: budget.spendBudget
                )

                sectionDivider

                // ── Section 2: Average daily ───────────────────────────────
                AverageDailySection(
                    averageDaily: averageDaily,
                    daysElapsed: daysElapsed,
                    totalSpent: totalSpent
                )

                sectionDivider

                // ── Section 3: Biggest expense ─────────────────────────────
                BiggestExpenseSection(transaction: biggestExpense)

                Color.clear.frame(height: 40)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, v in
            scrollOffset = -v
        }
        .scrollIndicators(.hidden)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(AppColors.charcoal.opacity(0.07))
            .frame(height: 0.5)
    }
}

// MARK: - Section 1: Category Spend

private struct CategorySpendSection: View {
    let categorySpends: [CategorySpendItem]
    let totalSpent: Double
    let spendBudget: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Category Spend")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.charcoal)
                    Text(BudgetFormatter.format(totalSpent) + " spent")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(AppColors.charcoal.opacity(0.4))
                }
                Spacer()
                if spendBudget > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Budget")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.charcoal.opacity(0.4))
                        Text(BudgetFormatter.format(spendBudget))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.charcoal)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 14)

            // Category bars
            if categorySpends.isEmpty {
                Text("No transactions yet this month")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppColors.charcoal.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(categorySpends) { item in
                    CategoryBarRow(item: item)
                }
            }

            Spacer(minLength: 0).frame(height: 14)
        }
    }
}

private struct CategoryBarRow: View {
    let item: CategorySpendItem

    var body: some View {
        // True Flighty style: single pill, emoji circle inside on left,
        // fill bar behind everything, text right-aligned
        ZStack(alignment: .leading) {
            // 1. Track background
            Capsule()
                .fill(AppColors.charcoal.opacity(0.07))

            // 2. Color fill — scaleEffect avoids GeometryReader entirely
            Capsule()
                .fill(item.color.opacity(0.20))
                .scaleEffect(x: max(0.015, item.fraction), y: 1, anchor: .leading)

            // 3. Content row (emoji left, text right)
            HStack(spacing: 0) {
                // Emoji circle inside pill on left
                ZStack {
                    Circle()
                        .fill(item.color)
                        .frame(width: 38, height: 38)
                    Text(item.emoji).font(.system(size: 17))
                }
                .padding(.leading, 4)

                Spacer(minLength: 8)

                // Amount + name right-aligned
                HStack(spacing: 5) {
                    Text(BudgetFormatter.format(item.amount))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.charcoal)
                    Text(item.name)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.charcoal.opacity(0.5))
                        .lineLimit(1)
                }
                .padding(.trailing, 14)
            }
        }
        .frame(height: 50)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
}

// MARK: - Section 2: Average Daily

private struct AverageDailySection: View {
    let averageDaily: Double
    let daysElapsed: Int
    let totalSpent: Double

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM"; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Average daily expense")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppColors.homeBlue.opacity(0.18)).frame(width: 44, height: 44)
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppColors.charcoal.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(BudgetFormatter.format(averageDaily) + " / day")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.charcoal)
                    Text("Based on \(daysElapsed) days elapsed")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(AppColors.charcoal.opacity(0.4))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(BudgetFormatter.format(totalSpent))
                        .font(.custom("Sora-SemiBold", size: 22))
                        .foregroundStyle(AppColors.charcoal)
                    Text("total")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.charcoal.opacity(0.35))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.charcoal.opacity(0.07)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Section 3: Biggest Expense

private struct BiggestExpenseSection: View {
    let transaction: Transaction?

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Biggest expense")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            if let t = transaction {
                HStack(alignment: .center, spacing: 14) {
                    // Category icon — same as TransactionRowView
                    ZStack {
                        Circle().fill(categoryColor(t.category).opacity(0.15)).frame(width: 44, height: 44)
                        Text(categoryEmoji(t.category)).font(.system(size: 18))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.merchant)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.charcoal)
                        Text("\(t.category) · \(Self.df.string(from: t.date))")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(AppColors.charcoal.opacity(0.4))
                    }

                    Spacer()

                    Text(compactINR(t.amount))
                        .font(.custom("Sora-SemiBold", size: 22))
                        .foregroundStyle(AppColors.charcoal)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                Text("No transactions yet")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppColors.charcoal.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            }
        }
    }

    private func categoryEmoji(_ name: String) -> String {
        AppCategory.defaults.first { $0.name == name }?.emoji ?? "💳"
    }
    private func categoryColor(_ name: String) -> Color {
        AppCategory.defaults.first { $0.name == name }?.color ?? AppColors.charcoal.opacity(0.5)
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
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)

            Text("Set your income and spending target\nto start tracking your month.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppColors.charcoal.opacity(0.45))
                .multilineTextAlignment(.center)

            Button(action: onCreate) {
                Text("CREATE BUDGET")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
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

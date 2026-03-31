
import SwiftUI
import SwiftData

private let kPeekFraction: CGFloat     = 0.45
private let kExpandedFraction: CGFloat = 0.22


struct SquaresDayHomeView: View {
    @Environment(TransactionStore.self) private var store
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @Binding var granularity: Granularity
    @State private var anchorDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var focusedBarID: String? = nil
    @State private var settingsOpen = false

    @State private var cardFraction: CGFloat = kPeekFraction
    @State private var dragOffset: CGFloat = 0
    @State private var listScrollOffset: CGFloat = 0
    @State private var isScrollEnabled = false

    // Cached derived state — only recomputed when data inputs change,
    // NOT on every drag frame or body re-evaluation.
    @State private var cachedBars: [ChartBar] = []
    @State private var cachedHeroHeadline: String = ""
    @State private var cachedHeroAmount: Double = 0
    @State private var cachedVisibleTransactions: [Transaction] = []

    private var currentRange: DateRange {
        dateRange(for: granularity, anchor: anchorDate)
    }

    private func recomputeDerivedState() {
        // Headline
        switch granularity {
        case .day:
            let cal = Calendar.current
            if cal.isDateInToday(anchorDate) { cachedHeroHeadline = "Today" }
            else if cal.isDateInYesterday(anchorDate) { cachedHeroHeadline = "Yesterday" }
            else { cachedHeroHeadline = anchorDate.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)) }
        case .week:
            let range = currentRange
            cachedHeroHeadline = "\(range.start.formatted(.dateTime.day().month(.abbreviated))) – \(range.end.formatted(.dateTime.day().month(.abbreviated)))"
        case .month:
            cachedHeroHeadline = anchorDate.formatted(.dateTime.month(.wide).year())
        }

        // Chart bars (computed once)
        let bars = store.chartBars(from: transactions, granularity: granularity, anchor: anchorDate)
        cachedBars = bars

        // Hero amount + visible transactions
        if let focused = focusedBarID,
           let bar = bars.first(where: { $0.id == focused }) {
            cachedHeroAmount = bar.amount
            cachedVisibleTransactions = store.filteredTransactions(
                transactions, in: DateRange(start: bar.periodStart, end: bar.periodEnd)
            ).sorted { $0.date > $1.date }
        } else {
            cachedHeroAmount = store.totalSpent(transactions, in: currentRange)
            cachedVisibleTransactions = store.filteredTransactions(transactions, in: currentRange)
                .sorted { $0.date > $1.date }
        }
    }

    private func snapCard(translationY: CGFloat, predictedY: CGFloat, screenH: CGFloat) {
        let peekY    = screenH * kPeekFraction
        let expandY  = screenH * kExpandedFraction
        let currentY = screenH * cardFraction + translationY
        let midY     = (peekY + expandY) / 2
        let velocity = predictedY - translationY
        let goExpand = currentY < midY || velocity < -200

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            cardFraction = goExpand ? kExpandedFraction : kPeekFraction
            dragOffset   = 0
        } completion: {
            isScrollEnabled = goExpand
        }
    }

    var body: some View {
        GeometryReader { geo in
            let screenH   = geo.size.height
            let peekY     = screenH * kPeekFraction
            let expandY   = screenH * kExpandedFraction
            let cardY     = max(expandY, min(peekY, screenH * cardFraction + dragOffset))
            let progress  = (cardY - expandY) / (peekY - expandY)
            let topRadius: CGFloat = 22 + (1 - progress) * 22

            ZStack(alignment: .top) {

                // ── 1. Blue background ────────────────────────────────────
                AppColors.homeBlue.ignoresSafeArea()

                // ── 2. Blue content — clipped to cardY ────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    DayHomeHeaderView()

                    HeroAmountView(
                        headline: cachedHeroHeadline,
                        amount: cachedHeroAmount,
                        granularity: $granularity,
                        onGranularityChange: { focusedBarID = nil }
                    )
                    .fixedSize(horizontal: false, vertical: true)

                    SpendingBarChartView(
                        bars: cachedBars,
                        focusedBarID: $focusedBarID
                    )
                    .opacity(progress)
                    .frame(height: progress < 0.01 ? 0 : nil, alignment: .top)

                    Spacer(minLength: 0)
                }
                .frame(height: cardY, alignment: .top)
                .clipped()

                // ── 3. Settings — native glass button ─────────────────────
                Button("Settings", systemImage: "gearshape") { settingsOpen = true }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 17, weight: .medium))
                    .buttonStyle(.glass)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 20)
                .padding(.top, 12)

                // ── 4. White card ─────────────────────────────────────────
                VStack(spacing: 0) {
                    TransactionCard(
                        transactions: cachedVisibleTransactions,
                        isExpanded: isScrollEnabled,
                        scrollOffset: $listScrollOffset
                    )
                    Color.white.frame(height: 400)
                }
                .offset(y: cardY)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: topRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: topRadius,
                        style: .continuous
                    )
                )
                .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: -4)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            isScrollEnabled = false
                            let dy = value.translation.height
                            let atListTop = listScrollOffset >= -1
                            if dy > 0 || atListTop {
                                dragOffset = dy
                            }
                        }
                        .onEnded { value in
                            let dy = value.translation.height
                            let atListTop = listScrollOffset >= -1
                            if dy > 0 || atListTop {
                                snapCard(
                                    translationY: value.translation.height,
                                    predictedY: value.predictedEndTranslation.height,
                                    screenH: screenH
                                )
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = abs(value.translation.height)
                        guard abs(dx) > dy, abs(dx) > 30 else { return }
                        let delta = dx < 0 ? 1 : -1
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            anchorDate   = shiftAnchor(anchorDate, granularity: granularity, delta: delta)
                            focusedBarID = nil
                        }
                    }
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { recomputeDerivedState() }
        .onChange(of: transactions) { recomputeDerivedState() }
        .onChange(of: granularity) { recomputeDerivedState() }
        .onChange(of: anchorDate) { recomputeDerivedState() }
        .onChange(of: focusedBarID) { recomputeDerivedState() }
        .sheet(isPresented: $settingsOpen) { SettingsView() }
    }
}

#Preview {
    SquaresDayHomeView(granularity: .constant(.day))
        .environment(TransactionStore())
        .modelContainer(SharedModelContainer.shared)
}

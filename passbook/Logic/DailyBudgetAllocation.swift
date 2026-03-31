
import Foundation

struct DayInput {
    let date: Date
    let spent: Double
    let isFuture: Bool
}

struct DayAllocation {
    let date: Date
    let baseBudget: Double
    let allocatedBudget: Double
    let spent: Double
    let remaining: Double
    let carryOver: Double
    let isOver: Bool
}

func dailyBudgetAllocation(baseDailyBudget: Double, days: [DayInput]) -> [DayAllocation] {
    var carryOver: Double = 0
    return days.map { day in
        let allocatedBudget = baseDailyBudget + carryOver
        let spent = day.isFuture ? 0 : day.spent
        let delta = allocatedBudget - spent
        let nextCarryOver = day.isFuture ? carryOver : delta
        carryOver = nextCarryOver
        return DayAllocation(
            date: day.date,
            baseBudget: baseDailyBudget,
            allocatedBudget: allocatedBudget,
            spent: spent,
            remaining: max(0, allocatedBudget - spent),
            carryOver: nextCarryOver,
            isOver: spent > allocatedBudget
        )
    }
}

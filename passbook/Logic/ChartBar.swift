import Foundation

struct ChartBar: Identifiable {
    let id: String
    let label: String
    let amount: Double
    let periodStart: Date
    let periodEnd: Date
}

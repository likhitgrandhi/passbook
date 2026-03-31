
import Foundation

func compactINR(_ amount: Double) -> String {
    func compact(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded(.towardZero) {
            return Int(rounded).formatted()
        }
        return rounded.formatted(.number.precision(.fractionLength(1...2)))
    }

    if amount >= 10_000_000 {
        return "₹\(compact(amount / 10_000_000))Cr"
    } else if amount >= 100_000 {
        return "₹\(compact(amount / 100_000))L"
    } else if amount >= 1_000 {
        return "₹\(compact(amount / 1_000))K"
    } else {
        return "₹\(compact(amount))"
    }
}

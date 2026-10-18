import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

enum Theme {
    static let accent = Color(hex: 0x56704F)
    static let background = Color(hex: 0xFBFAF7)
    static let grouped = Color(hex: 0xF4F2EE)
    static let ink = Color(hex: 0x1C1B19)
    static let secondary = Color(hex: 0x8A8780)
    static let chip = Color(hex: 0xEFEDE8)
    static let danger = Color(hex: 0xD9534A)
    static let amberBg = Color(hex: 0xF8EFE0)
    static let amberFg = Color(hex: 0x7A531A)
    static let sageBg = Color(hex: 0xE9EFE6)
    static let sageFg = Color(hex: 0x3F5A3D)
}

/// How an item's cost per use compares to its target.
enum ValueTone {
    case great, gettingThere, underUsed

    init(costPerUse c: Double, target t: Double) {
        self = c <= t * 1.6 ? .great : c <= t * 3 ? .gettingThere : .underUsed
    }
    var background: Color {
        switch self {
        case .great: Color(hex: 0xE7EEE3)
        case .gettingThere: Color(hex: 0xE5ECF3)
        case .underUsed: Color(hex: 0xF6ECDA)
        }
    }
    var foreground: Color {
        switch self {
        case .great: Color(hex: 0x3F5A3D)
        case .gettingThere: Color(hex: 0x3D5672)
        case .underUsed: Color(hex: 0x8A5F1E)
        }
    }
    var bar: Color {
        switch self {
        case .great: Color(hex: 0x7E9A79)
        case .gettingThere: Color(hex: 0x7F97B2)
        case .underUsed: Color(hex: 0xC9A066)
        }
    }
    var label: String {
        switch self {
        case .great: "Great value"
        case .gettingThere: "Getting there"
        case .underUsed: "Under-used"
        }
    }
}

/// "$1,240" for large amounts, "$2.35" for small ones.
func fmt(_ n: Double) -> String {
    if n >= 100 { return money(n) }
    return "$" + String(format: "%.2f", n)
}

func money(_ n: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return "$" + (f.string(from: NSNumber(value: n.rounded())) ?? "0")
}

func lastUsedText(_ days: Int) -> String {
    days <= 0 ? "Today" : days == 1 ? "Yesterday" : "\(days) days ago"
}

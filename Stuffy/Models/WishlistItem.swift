import Foundation
import SwiftData

enum WishStatus: String {
    case waiting, declined, bought
}

@Model
final class WishlistItem {
    var brand: String = ""
    var name: String = ""
    var price: Double = 0
    var addedDate: Date = Date()
    var decidedDate: Date?
    var statusRaw: String = WishStatus.waiting.rawValue
    @Attribute(.externalStorage) var photoData: Data?

    var category: Category?

    init(brand: String, name: String, price: Double, category: Category? = nil, photoData: Data? = nil) {
        self.brand = brand
        self.name = name
        self.price = price
        self.category = category
        self.photoData = photoData
    }

    var status: WishStatus {
        get { WishStatus(rawValue: statusRaw) ?? .waiting }
        set { statusRaw = newValue.rawValue }
    }
    var title: String { brand.isEmpty ? name : "\(brand) \(name)" }

    /// Expensive items get a longer hold.
    func holdDays(default days: Int) -> Int { price > 1000 ? 30 : days }
    func daysIn(now: Date = Date()) -> Int { Item.days(from: addedDate, to: now) }
    func daysLeft(default days: Int, now: Date = Date()) -> Int { max(0, holdDays(default: days) - daysIn(now: now)) }
}

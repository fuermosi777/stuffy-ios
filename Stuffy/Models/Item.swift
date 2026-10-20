import Foundation
import SwiftData

enum ItemStatus: String {
    case active, retired, sold
}

/// CloudKit-compatible: every property has a default, relationships are optional.
@Model
final class Item {
    var brand: String = ""
    var name: String = ""
    var price: Double = 0
    var purchaseDate: Date = Date()
    var targetCostPerUse: Double = 2
    /// Uses that happened before the item was added to Stuffy.
    var initialUses: Int = 0
    var statusRaw: String = ItemStatus.active.rawValue
    var endedDate: Date?
    var resalePrice: Double = 0
    var notes: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date = Date()

    var category: Category?
    @Relationship(deleteRule: .cascade, inverse: \UsageLog.item) var logs: [UsageLog]?

    init(brand: String, name: String, price: Double, purchaseDate: Date = Date(),
         targetCostPerUse: Double = 2, initialUses: Int = 0, category: Category? = nil, photoData: Data? = nil) {
        self.brand = brand
        self.name = name
        self.price = price
        self.purchaseDate = purchaseDate
        self.targetCostPerUse = targetCostPerUse
        self.initialUses = initialUses
        self.category = category
        self.photoData = photoData
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
    var isActive: Bool { status == .active }
    var title: String { brand.isEmpty ? name : "\(brand) \(name)" }

    var uses: Int { initialUses + (logs?.count ?? 0) }
    var sortedLogs: [UsageLog] { (logs ?? []).sorted { $0.date > $1.date } }

    var lastUsed: Date? {
        if let d = logs?.map(\.date).max() { return d }
        return initialUses > 0 ? purchaseDate : nil
    }
    /// Days since last use (or since purchase if never used).
    func idleDays(now: Date = Date()) -> Int {
        Item.days(from: lastUsed ?? purchaseDate, to: now)
    }

    /// Price minus what was recovered by selling.
    var netCost: Double { max(0, price - (status == .sold ? resalePrice : 0)) }
    var costPerUse: Double { netCost / Double(max(1, uses)) }

    func daysOwned(now: Date = Date()) -> Int {
        max(1, Item.days(from: purchaseDate, to: endedDate ?? now))
    }
    func costPerDay(now: Date = Date()) -> Double { netCost / Double(daysOwned(now: now)) }

    /// Uses needed for the cost per use to reach `target`.
    func usesNeeded(for target: Double) -> Int { Int((netCost / target).rounded(.up)) }

    var tone: ValueTone { ValueTone(costPerUse: costPerUse, target: targetCostPerUse) }

    static func days(from a: Date, to b: Date) -> Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: a), to: Calendar.current.startOfDay(for: b)).day ?? 0
    }
}

@Model
final class UsageLog {
    var date: Date = Date()
    var item: Item?

    init(date: Date = Date(), item: Item? = nil) {
        self.date = date
        self.item = item
    }
}

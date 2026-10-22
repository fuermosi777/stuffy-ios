import Foundation
import SwiftData

@Model
final class Category {
    var name: String = ""
    var symbol: String = "tag"
    var sortOrder: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \Item.category) var items: [Item]?
    /// The one item worn every day; it earns a wear per calendar day. See `DailyDriver`.
    @Relationship(deleteRule: .nullify, inverse: \Item.dailyOf) var dailyItem: Item?
    /// First day the daily driver hasn't been credited for yet.
    var dailyCursor: Date?
    @Relationship(deleteRule: .nullify, inverse: \WishlistItem.category) var wishes: [WishlistItem]?

    init(name: String, symbol: String = "tag", sortOrder: Int = 0) {
        self.name = name
        self.symbol = symbol
        self.sortOrder = sortOrder
    }

    static let defaults: [(name: String, symbol: String)] = [
        ("Shoes", "shoe"),
        ("Apparel", "tshirt"),
        ("Bags", "bag"),
        ("Tech", "laptopcomputer"),
        ("Accessories", "eyeglasses"),
    ]

    static func seedIfNeeded(in context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard count == 0 else { return }
        for (i, d) in defaults.enumerated() {
            context.insert(Category(name: d.name, symbol: d.symbol, sortOrder: i))
        }
    }

    /// Two devices can seed defaults before their first sync; merge same-named categories.
    static func mergeDuplicates(in context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)])) else { return }
        var keepers: [String: Category] = [:]
        for c in all {
            let key = c.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard let keeper = keepers[key] else { keepers[key] = c; continue }
            for item in c.items ?? [] { item.category = keeper }
            for wish in c.wishes ?? [] { wish.category = keeper }
            context.delete(c)
        }
    }
}

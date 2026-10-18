import Foundation
import SwiftData

@Model
final class Category {
    var name: String = ""
    var symbol: String = "tag"
    var sortOrder: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \Item.category) var items: [Item]?
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
}

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WishlistItem> { $0.statusRaw == "waiting" }) private var wishes: [WishlistItem]
    @AppStorage("holdDays") private var holdDays = 14

    var body: some View {
        TabView {
            Tab("Items", systemImage: "shippingbox") { ItemsView() }
            Tab("Insights", systemImage: "chart.line.uptrend.xyaxis") { InsightsView() }
            Tab("Wishlist", systemImage: "hourglass") { WishlistView() }
                .badge(readyCount)
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
        .task { Category.seedIfNeeded(in: context) }
    }

    private var readyCount: Int {
        wishes.filter { $0.daysLeft(default: holdDays) == 0 }.count
    }
}

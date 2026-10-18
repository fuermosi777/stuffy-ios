import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WishlistItem> { $0.statusRaw == "waiting" }) private var wishes: [WishlistItem]
    @Query private var categories: [Category]
    @AppStorage("holdDays") private var holdDays = 14
    @State private var icloud = ICloudStatus()

    var body: some View {
        TabView {
            Tab("Items", systemImage: "shippingbox") { ItemsView() }
            Tab("Insights", systemImage: "chart.line.uptrend.xyaxis") { InsightsView() }
            Tab("Wishlist", systemImage: "hourglass") { WishlistView() }
                .badge(readyCount)
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
        .environment(icloud)
        .task {
            await icloud.refresh()
            // Wait briefly for a first sync so a second device doesn't re-seed the defaults.
            if icloud.isAvailable { try? await Task.sleep(for: .seconds(3)) }
            Category.seedIfNeeded(in: context)
        }
        .onChange(of: categories.count) { Category.mergeDuplicates(in: context) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await icloud.refresh() }
        }
    }

    private var readyCount: Int {
        wishes.filter { $0.daysLeft(default: holdDays) == 0 }.count
    }
}

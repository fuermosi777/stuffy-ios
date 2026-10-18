import SwiftUI
import SwiftData

@main
struct StuffyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Category.self, Item.self, UsageLog.self, WishlistItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}

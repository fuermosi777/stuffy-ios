import SwiftUI
import SwiftData

/// Home-screen reminder of which items are counting a wear every day.
struct DailyDriverStrip: View {
    let categories: [Category]
    var onTap: (Category) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill").foregroundStyle(Theme.accent)
                Text("Daily drivers").font(.system(size: 13, weight: .semibold)).textCase(.uppercase)
                Text("· +1 wear a day, until you switch").font(.system(size: 13))
            }
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories) { c in
                        if let item = c.dailyItem {
                            Button { onTap(c) } label: {
                                Card {
                                    HStack(spacing: 10) {
                                        PhotoThumb(data: item.photoData, symbol: c.symbol, size: 44, radius: 10)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(c.name.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.4)
                                                .foregroundStyle(Theme.secondary)
                                            Text(item.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                                            Text("\(item.uses) wears").font(.system(size: 12)).monospacedDigit().foregroundStyle(Theme.secondary)
                                        }
                                        .lineLimit(1)
                                        Image(systemName: "arrow.left.arrow.right").font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Theme.secondary)
                                    }
                                    .padding(10)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(c.name) daily driver: \(item.name). Tap to change.")
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 6)
            }
        }
        .padding(.bottom, 8)
    }
}

/// Pick, switch or clear a category's daily driver.
struct DailyDriverSheet: View {
    let category: Category
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var candidates: [Item] {
        (category.items ?? []).filter(\.isActive).sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(candidates) { item in
                        Button { DailyDriver.assign(item, in: context); dismiss() } label: {
                            HStack(spacing: 12) {
                                PhotoThumb(data: item.photoData, symbol: category.symbol, size: 40, radius: 10)
                                Text(item.title).foregroundStyle(Theme.ink)
                                Spacer()
                                if category.dailyItem === item { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                            }
                        }
                    }
                    Button { DailyDriver.clear(category); dismiss() } label: {
                        HStack {
                            Text("None").foregroundStyle(Theme.ink)
                            Spacer()
                            if category.dailyItem == nil { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                        }
                    }
                } footer: {
                    Text("The daily driver gets a wear every calendar day until you switch or clear it. Logging a different \(category.name.lowercased()) item by hand replaces that day.")
                }
            }
            .navigationTitle("\(category.name) daily driver").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

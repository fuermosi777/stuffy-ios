import SwiftUI
import SwiftData

/// Home-screen reminder of which items are counting a wear every day.
struct DailyDriverStrip: View {
    let items: [Item]
    var onTap: (Category) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill").foregroundStyle(Theme.accent)
                Text("Daily drivers").font(.system(size: 13, weight: .semibold)).textCase(.uppercase)
                Text("· +1 wear a day, until you turn them off").font(.system(size: 13))
            }
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        if let c = item.dailyOf {
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
                                        Image(systemName: "slider.horizontal.3").font(.system(size: 12, weight: .semibold))
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

/// Turn daily drivers on or off for a category's items.
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
                        let on = item.dailyOf != nil
                        Button {
                            if on { DailyDriver.clear(item) } else { DailyDriver.assign(item, in: context) }
                        } label: {
                            HStack(spacing: 12) {
                                PhotoThumb(data: item.photoData, symbol: category.symbol, size: 40, radius: 10)
                                Text(item.title).foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(on ? Theme.accent : Theme.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Daily drivers get a wear every calendar day until you turn them off. Logging one by hand just replaces its automatic wear for that day.")
                }
            }
            .navigationTitle("\(category.name) daily drivers").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

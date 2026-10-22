import SwiftUI
import SwiftData

struct ItemsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Item.createdAt, order: .reverse) private var allItems: [Item]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var filter: Category?
    @State private var query = ""
    @State private var selected: Item?
    @State private var showingAdd = false
    @State private var switching: Category?
    @State private var toast: Toast?

    private var active: [Item] { allItems.filter(\.isActive) }

    private var feed: [Item] {
        active
            .filter { filter == nil || $0.category == filter }
            .filter { matches($0) }
            .sorted { $0.idleDays() < $1.idleDays() }
    }

    private var drivers: [Item] {
        guard query.isEmpty else { return [] }
        return active
            .filter { $0.dailyOf != nil && (filter == nil || $0.category == filter) }
            .sorted { ($0.category?.sortOrder ?? 0, $0.title) < ($1.category?.sortOrder ?? 0, $1.title) }
    }

    private func matches(_ item: Item) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        return "\(item.title) \(item.category?.name ?? "")".lowercased().contains(q)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text(summary).font(.system(size: 14)).foregroundStyle(Theme.secondary)
                        .padding(.horizontal, 20).padding(.top, 2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryChip(label: "All", selected: filter == nil) { filter = nil }
                            ForEach(categories) { c in
                                CategoryChip(label: c.name, selected: filter == c) { filter = c }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 14)

                    if !drivers.isEmpty { DailyDriverStrip(items: drivers) { switching = $0 } }

                    if feed.isEmpty {
                        emptyState
                    } else {
                        ForEach(feed) { item in
                            ItemRow(item: item, onOpen: { selected = item }, onLog: { log(item) })
                            Divider().padding(.leading, 96)
                        }
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Stuffy")
            .searchable(text: $query, prompt: "Search your stuff")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add item")
                }
            }
            .sheet(item: $selected) { ItemDetailView(item: $0) }
            .sheet(isPresented: $showingAdd) { ItemFormView(item: nil) }
            .sheet(item: $switching) { DailyDriverSheet(category: $0) }
            .toast($toast)
        }
    }

    private var summary: String {
        let value = active.reduce(0) { $0 + $1.netCost }
        let uses = active.reduce(0) { $0 + $1.uses }
        return "\(active.count) items · \(fmt(value / Double(max(1, uses)))) avg per wear"
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox").font(.system(size: 34)).foregroundStyle(Theme.secondary)
            Text(active.isEmpty ? "Nothing here yet" : "No matches").font(.headline)
            Text(active.isEmpty ? "Tap + to add the first thing you own." : "Try another category or search.")
                .font(.subheadline).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 80)
    }

    private func log(_ item: Item) {
        let before = item.costPerUse
        let added = item.logWear(in: context)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        toast = added
            ? Toast(title: "Logged a wear", subtitle: "\(item.name) · \(fmt(before)) → \(fmt(item.costPerUse))")
            : Toast(title: "Already counted today", subtitle: "\(item.name) is a daily driver")
    }
}

struct ItemRow: View {
    let item: Item
    var onOpen: () -> Void
    var onLog: () -> Void
    @State private var bump = false

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    PhotoThumb(data: item.photoData, symbol: item.category?.symbol ?? "photo", size: 68)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(item.brand.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.4)
                                .foregroundStyle(Theme.secondary).lineLimit(1)
                            if item.dailyOf != nil {
                                Label("Daily", systemImage: "sun.max.fill").font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.accent).fixedSize()
                            }
                        }
                        Text(item.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                        Text("\(item.uses) wears")
                            .font(.system(size: 13)).monospacedDigit().foregroundStyle(bump ? Theme.sageFg : Theme.secondary)
                            .scaleEffect(bump ? 1.2 : 1, anchor: .leading)
                        HStack(spacing: 6) {
                            Pill(text: "\(fmt(item.costPerUse))/wear", background: item.tone.background, foreground: item.tone.foreground)
                            Pill(text: "\(fmt(item.costPerDay()))/day", background: Theme.chip, foreground: Color(hex: 0x55524C))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onLog()
                withAnimation(.spring(duration: 0.35, bounce: 0.5)) { bump = true }
                Task { try? await Task.sleep(for: .milliseconds(700)); withAnimation { bump = false } }
            } label: {
                Image(systemName: bump ? "checkmark" : "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(bump ? Theme.sageFg : Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(bump ? Theme.sageBg : Color(hex: 0xF2F0EB), in: Circle())
            }
            .accessibilityLabel("Log a wear")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }
}

import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @Query private var allItems: [Item]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var wishlist: [WishlistItem]
    @AppStorage("idleDays") private var idleThreshold = 45
    @State private var selected: Item?
    @State private var toast: Toast?

    private var active: [Item] { allItems.filter(\.isActive) }
    private var sold: [Item] { allItems.filter { $0.status == .sold } }

    private var totalValue: Double { active.reduce(0) { $0 + $1.netCost } }
    private var portfolio: Double { totalValue / Double(max(1, active.reduce(0) { $0 + $1.uses })) }

    /// Portfolio cost per wear at the end of each of the last 6 months.
    private var trend: [(label: String, value: Double)] {
        let cal = Calendar.current
        return (0..<6).reversed().compactMap { back in
            guard let month = cal.date(byAdding: .month, value: -back, to: Date()),
                  let start = cal.dateInterval(of: .month, for: month)?.start else { return nil }
            let end = back == 0 ? Date() : (cal.date(byAdding: .month, value: 1, to: start) ?? Date())
            let owned = active.filter { $0.purchaseDate <= end }
            let cost = owned.reduce(0) { $0 + $1.netCost }
            let uses = owned.reduce(0) { sum, i in sum + i.initialUses + (i.logs ?? []).filter { $0.date <= end }.count }
            guard !owned.isEmpty else { return nil }
            return (start.formatted(.dateTime.month(.abbreviated)), cost / Double(max(1, uses)))
        }
    }

    private var idle: [Item] { active.filter { $0.idleDays() >= idleThreshold }.sorted { $0.idleDays() > $1.idleDays() } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(money(totalValue)) across \(active.count) items").font(.system(size: 14)).foregroundStyle(Theme.secondary)
                    portfolioCard
                    highlights
                    ActivityCalendarView(items: allItems, wishlist: wishlist) { selected = $0 }
                    categoryCard
                    graveyard
                    if !sold.isEmpty { recovered }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Insights")
            .sheet(item: $selected) { ItemDetailView(item: $0) }
            .toast($toast)
        }
    }

    private var portfolioCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Average cost per wear").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary)
                Text(fmt(portfolio)).font(.system(size: 40, weight: .bold)).monospacedDigit()
                Text("Owning everything costs \(fmt(active.reduce(0) { $0 + $1.costPerDay() }))/day")
                    .font(.system(size: 14)).foregroundStyle(Theme.secondary)
                if trend.count > 1 {
                    Chart(trend, id: \.label) {
                        AreaMark(x: .value("Month", $0.label), y: .value("CPW", $0.value)).foregroundStyle(Theme.accent.opacity(0.12))
                        LineMark(x: .value("Month", $0.label), y: .value("CPW", $0.value)).foregroundStyle(Theme.accent)
                            .interpolationMethod(.monotone)
                    }
                    .chartYAxis(.hidden)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 110).padding(.top, 10)
                }
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var highlights: some View {
        if let top = active.max(by: { $0.uses < $1.uses }), let best = active.min(by: { $0.costPerUse < $1.costPerUse }) {
            VStack(spacing: 10) {
                highlight("trophy", "Most worn", top.title, "\(top.uses)×", top)
                highlight("sparkles", "Best value", best.title, "\(fmt(best.costPerUse))/wear", best)
            }
        }
    }

    private func highlight(_ symbol: String, _ label: String, _ name: String, _ value: String, _ item: Item) -> some View {
        Button { selected = item } label: {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: symbol).foregroundStyle(Theme.sageFg).frame(width: 36, height: 36)
                        .background(Theme.sageBg, in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.secondary)
                        Text(name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    }
                    Spacer()
                    Text(value).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
    }

    private var categoryStats: [(name: String, value: Double, tone: ValueTone)] {
        categories.compactMap { c in
            let its = active.filter { $0.category == c }
            guard !its.isEmpty else { return nil }
            let v = its.reduce(0) { $0 + $1.netCost } / Double(max(1, its.reduce(0) { $0 + $1.uses }))
            let t = its.reduce(0) { $0 + $1.targetCostPerUse } / Double(its.count)
            return (c.name, v, ValueTone(costPerUse: v, target: t))
        }
    }

    @ViewBuilder private var categoryCard: some View {
        let stats = categoryStats
        if !stats.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Cost per wear by category")
                Card {
                    VStack(spacing: 14) {
                        ForEach(stats, id: \.name) { s in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(s.name).font(.system(size: 15, weight: .medium)); Spacer()
                                    Text(fmt(s.value)).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(s.tone.foreground) }
                                GeometryReader { g in
                                    Capsule().fill(s.tone.bar)
                                        .frame(width: max(8, g.size.width * s.value / (stats.map(\.value).max() ?? 1)))
                                }
                                .frame(height: 8)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var graveyard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Graveyard")
            Text(idle.isEmpty ? "Nothing idle right now" : "\(money(idle.reduce(0) { $0 + $1.netCost })) untouched for \(idleThreshold)+ days")
                .font(.system(size: 14)).foregroundStyle(Theme.secondary)
            ForEach(idle) { item in
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Button { selected = item } label: {
                            HStack(spacing: 12) {
                                PhotoThumb(data: item.photoData, symbol: item.category?.symbol ?? "photo", size: 52, radius: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                                    Text("\(item.uses) wears · \(fmt(item.costPerUse))/wear").font(.system(size: 13)).foregroundStyle(Theme.secondary)
                                    Text("Idle \(item.idleDays()) days").font(.system(size: 13)).foregroundStyle(ValueTone.underUsed.foreground)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        HStack(spacing: 8) {
                            action("Wear it", Theme.sageBg, Theme.sageFg) {
                                context.insert(UsageLog(item: item))
                                toast = Toast(title: "Back in rotation", subtitle: item.name)
                            }
                            action("Retire", Theme.chip, Theme.ink) { item.status = .retired; item.endedDate = Date() }
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    private func action(_ label: String, _ bg: Color, _ fg: Color, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(fg)
                .frame(maxWidth: .infinity).frame(height: 36).background(bg, in: Capsule())
        }
    }

    private var recovered: some View {
        Card {
            HStack {
                Image(systemName: "arrow.3.trianglepath").foregroundStyle(Theme.sageFg)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Recovered from resale").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.secondary)
                    Text(money(sold.reduce(0) { $0 + $1.resalePrice })).font(.system(size: 22, weight: .bold)).monospacedDigit()
                }
                Spacer()
                Text("\(sold.count) sold").font(.system(size: 14)).foregroundStyle(Theme.secondary)
            }
            .padding(16)
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary).textCase(.uppercase)
    }
}

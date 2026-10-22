import SwiftUI
import SwiftData
import Charts

/// What was bought each year: money spent and number of items, split by category.
struct YearlyView: View {
    let items: [Item]
    var onSelect: (Item) -> Void

    @State private var metric: Metric = .spent
    @State private var year = Calendar.current.component(.year, from: Date())

    enum Metric: String, CaseIterable { case spent = "Spent", count = "Items" }

    private struct Slice: Identifiable {
        let year: Int
        let category: String
        let spent: Double
        let count: Int
        var id: String { "\(year)-\(category)" }
    }

    private static let palette: [Color] = [
        Theme.accent, Color(hex: 0x7F97B2), Color(hex: 0xC9A066), Color(hex: 0xB07A6B),
        Color(hex: 0x8E7FA3), Color(hex: 0x6FA3A0), Color(hex: 0xA8A38F), Color(hex: 0xC48B9F),
    ]

    private func yearOf(_ item: Item) -> Int { Calendar.current.component(.year, from: item.purchaseDate) }
    private func categoryName(_ item: Item) -> String { item.category?.name ?? "Other" }

    private var byYear: [Int: [Item]] { Dictionary(grouping: items, by: yearOf) }

    /// Every year from the first purchase to now, so gaps show as empty.
    private var years: [Int] {
        let now = Calendar.current.component(.year, from: Date())
        let first = min(byYear.keys.min() ?? now, now)
        return Array(first...now)
    }

    private var categoryNames: [String] {
        var seen: [String] = []
        for i in items.sorted(by: { ($0.category?.sortOrder ?? .max) < ($1.category?.sortOrder ?? .max) }) {
            let n = categoryName(i)
            if !seen.contains(n) { seen.append(n) }
        }
        return seen
    }

    private var slices: [Slice] {
        years.flatMap { y -> [Slice] in
            let its = byYear[y] ?? []
            guard !its.isEmpty else { return [Slice(year: y, category: categoryNames.first ?? "Other", spent: 0, count: 0)] }
            return Dictionary(grouping: its, by: categoryName).map { name, group in
                Slice(year: y, category: name, spent: group.reduce(0) { $0 + $1.price }, count: group.count)
            }
        }
    }

    var body: some View {
        if items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar").font(.system(size: 34)).foregroundStyle(Theme.secondary)
                Text("Nothing bought yet").font(.headline)
                Text("Add items and each year's spending shows up here.").font(.subheadline).foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity).padding(.top, 60)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                chartCard
                yearTable
                yearItems
            }
        }
    }

    private var chartCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Metric", selection: $metric) {
                    ForEach(Metric.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Chart(slices) { s in
                    BarMark(x: .value("Year", String(s.year)),
                            y: .value(metric.rawValue, metric == .spent ? s.spent : Double(s.count)))
                        .foregroundStyle(by: .value("Category", s.category))
                        .opacity(s.year == year ? 1 : 0.4)
                }
                .chartXScale(domain: years.map(String.init))
                .chartForegroundStyleScale(domain: categoryNames,
                                           range: categoryNames.indices.map { Self.palette[$0 % Self.palette.count] })
                .chartLegend(position: .bottom, alignment: .leading)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(metric == .spent ? compactMoney(v) : "\(Int(v))") }
                        }
                    }
                }
                .frame(height: 220)
            }
            .padding(16)
        }
    }

    private var yearTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By year").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary).textCase(.uppercase)
            Card {
                VStack(spacing: 0) {
                    ForEach(Array(years.reversed().enumerated()), id: \.element) { i, y in
                        if i > 0 { Divider() }
                        let its = byYear[y] ?? []
                        Button { year = y } label: {
                            HStack {
                                Text(String(y)).font(.system(size: 16, weight: y == year ? .bold : .medium))
                                Spacer()
                                Text("\(its.count) \(its.count == 1 ? "item" : "items")")
                                    .font(.system(size: 14)).foregroundStyle(Theme.secondary).monospacedDigit()
                                Text(money(its.reduce(0) { $0 + $1.price }))
                                    .font(.system(size: 16, weight: .semibold)).monospacedDigit().frame(minWidth: 80, alignment: .trailing)
                            }
                            .foregroundStyle(Theme.ink)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder private var yearItems: some View {
        let its = (byYear[year] ?? []).sorted { $0.price > $1.price }
        if !its.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Bought in \(String(year))").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary).textCase(.uppercase)
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(its.enumerated()), id: \.element.persistentModelID) { i, item in
                            if i > 0 { Divider().padding(.leading, 68) }
                            Button { onSelect(item) } label: {
                                HStack(spacing: 12) {
                                    PhotoThumb(data: item.photoData, symbol: item.category?.symbol ?? "photo", size: 44, radius: 10)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                                        Text([categoryName(item), item.purchaseDate.formatted(.dateTime.month(.abbreviated).day()),
                                              item.isActive ? nil : item.status == .sold ? "Sold" : "Retired"]
                                            .compactMap { $0 }.joined(separator: " · "))
                                            .font(.system(size: 13)).foregroundStyle(Theme.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(money(item.price)).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func compactMoney(_ n: Double) -> String {
        n >= 1000 ? "$" + String(format: n >= 10_000 ? "%.0fk" : "%.1fk", n / 1000) : money(n)
    }
}

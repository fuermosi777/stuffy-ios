import SwiftUI

/// Month grid of wears (heat), purchases and declined wishlist items, with a per-day breakdown.
struct ActivityCalendarView: View {
    let items: [Item]
    let wishlist: [WishlistItem]
    var onOpen: (Item) -> Void

    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())!.start
    @State private var selected = Calendar.current.startOfDay(for: Date())

    private let cal = Calendar.current
    private let blue = Color(hex: 0x4D6887), blueBg = Color(hex: 0xE8EEF4), blueFg = Color(hex: 0x3D5672)
    private let gold = Color(hex: 0xC9A066), goldBg = Color(hex: 0xF6EEDF), goldFg = Color(hex: 0x8A5F1E)

    private var isCurrentMonth: Bool { cal.isDate(month, equalTo: Date(), toGranularity: .month) }
    private var declined: [WishlistItem] { wishlist.filter { $0.status == .declined && $0.decidedDate != nil } }

    private func wears(on day: Date) -> [Item: Int] {
        var out: [Item: Int] = [:]
        for i in items {
            let n = (i.logs ?? []).filter { cal.isDate($0.date, inSameDayAs: day) }.count
            if n > 0 { out[i] = n }
        }
        return out
    }
    private func bought(on day: Date) -> [Item] { items.filter { cal.isDate($0.purchaseDate, inSameDayAs: day) } }
    private func declined(on day: Date) -> [WishlistItem] { declined.filter { cal.isDate($0.decidedDate!, inSameDayAs: day) } }

    private var days: [Date] {
        let n = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        return (0..<n).compactMap { cal.date(byAdding: .day, value: $0, to: month) }
    }
    private var leadingBlanks: Int { cal.component(.weekday, from: month) - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity calendar").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary).textCase(.uppercase)
            Card { calendarCard }
            Card { dayCard }
        }
    }

    // MARK: Month card

    private var calendarCard: some View {
        let monthDays = days
        let monthWears = monthDays.reduce(0) { $0 + wears(on: $1).values.reduce(0, +) }
        let buys = monthDays.flatMap { bought(on: $0) }
        let saved = monthDays.flatMap { declined(on: $0) }.reduce(0) { $0 + $1.price }
        return VStack(spacing: 0) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year())).font(.system(size: 20, weight: .bold))
                Spacer()
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 34, height: 34) }
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 34, height: 34) }
                    .disabled(isCurrentMonth)
            }
            .foregroundStyle(Theme.accent).padding(.horizontal, 6)

            HStack(spacing: 8) {
                stat("\(monthWears)", "wears", Theme.sageBg, Theme.sageFg)
                stat("\(buys.count)", buys.isEmpty ? "bought" : "bought · \(money(buys.reduce(0) { $0 + $1.price }))", blueBg, blueFg)
                stat(money(saved), "saved", goldBg, goldFg)
            }
            .padding(.horizontal, 6).padding(.top, 12).padding(.bottom, 14)

            HStack(spacing: 0) {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, d in
                    Text(d).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(hex: 0xA29E96)).frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 46) }
                ForEach(monthDays, id: \.self) { dayCell($0) }
            }

            HStack {
                HStack(spacing: 4) {
                    Text("Less")
                    ForEach([0xF1EFEA, 0xE3EBDF, 0xC9D8C3, 0x9DB596] as [UInt32], id: \.self) { Circle().fill(Color(hex: $0)).frame(width: 10, height: 10) }
                    Text("More wears")
                }
                Spacer()
                HStack(spacing: 10) {
                    HStack(spacing: 4) { Circle().fill(blue).frame(width: 6, height: 6); Text("Bought") }
                    HStack(spacing: 4) { Circle().fill(gold).frame(width: 6, height: 6); Text("Declined") }
                }
            }
            .font(.system(size: 12)).foregroundStyle(Theme.secondary).padding(.horizontal, 6).padding(.top, 10)
        }
        .padding(.top, 16).padding(.horizontal, 12).padding(.bottom, 12)
    }

    private func stat(_ value: String, _ label: String, _ bg: Color, _ fg: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 20, weight: .bold)).monospacedDigit().foregroundStyle(fg)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(fg.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
        .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder private func dayCell(_ day: Date) -> some View {
        let future = day > Date() && !cal.isDateInToday(day)
        let isSel = cal.isDate(day, inSameDayAs: selected), today = cal.isDateInToday(day)
        let w = wears(on: day).values.reduce(0, +)
        let heat: Color = w == 0 ? .clear : w <= 2 ? Color(hex: 0xE3EBDF) : w <= 4 ? Color(hex: 0xC9D8C3) : Color(hex: 0x9DB596)
        Button { selected = day } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 15, weight: isSel || today ? .bold : .medium)).monospacedDigit()
                    .foregroundStyle(isSel ? Theme.background : today ? Theme.accent : future ? Color(hex: 0xC2BEB5) : Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(isSel ? Theme.ink : heat, in: Circle())
                    .overlay { if today && !isSel { Circle().strokeBorder(Theme.accent, lineWidth: 1.5) } }
                HStack(spacing: 3) {
                    Circle().fill(blue).frame(width: 4, height: 4).opacity(bought(on: day).isEmpty ? 0 : 1)
                    Circle().fill(gold).frame(width: 4, height: 4).opacity(declined(on: day).isEmpty ? 0 : 1)
                }
                .frame(height: 4)
            }
            .frame(height: 46).frame(maxWidth: .infinity).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(future)
    }

    private func shift(_ by: Int) {
        guard let m = cal.date(byAdding: .month, value: by, to: month) else { return }
        month = m
    }

    // MARK: Selected day

    private var dayCard: some View {
        let w = wears(on: selected).sorted { $0.key.title < $1.key.title }
        let b = bought(on: selected), d = declined(on: selected)
        let wearCount = w.reduce(0) { $0 + $1.value }
        let summary = [wearCount > 0 ? "\(wearCount) \(wearCount == 1 ? "wear" : "wears")" : nil,
                       b.isEmpty ? nil : "\(b.count) bought", d.isEmpty ? nil : "\(d.count) declined"]
            .compactMap { $0 }.joined(separator: " · ")
        let title = (cal.isDateInToday(selected) ? "Today · " : "") + selected.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(summary).font(.system(size: 13)).foregroundStyle(Theme.secondary).monospacedDigit()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            ForEach(b) { i in
                row(i.title, "Purchased · \(i.category?.name ?? "")", fmt(i.price), blueBg, blueFg, i.photoData, i.category?.symbol) { onOpen(i) }
            }
            ForEach(w, id: \.key) { i, n in
                row(i.title, "Worn · now \(fmt(i.costPerUse))/wear", "×\(n)", Theme.sageBg, Theme.sageFg, i.photoData, i.category?.symbol) { onOpen(i) }
            }
            ForEach(d) { x in
                row(x.title, "Declined after cooling-off", "+\(money(x.price))", goldBg, goldFg, x.photoData, x.category?.symbol, nil)
            }
            if b.isEmpty && w.isEmpty && d.isEmpty {
                Divider()
                Text("No activity this day.").font(.system(size: 15)).foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
            }
        }
    }

    private func row(_ title: String, _ sub: String, _ tag: String, _ bg: Color, _ fg: Color,
                     _ photo: Data?, _ symbol: String?, _ open: (() -> Void)?) -> some View {
        VStack(spacing: 0) {
            Divider()
            Button { open?() } label: {
                HStack(spacing: 12) {
                    PhotoThumb(data: photo, symbol: symbol ?? "photo", size: 38, radius: 10)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title).font(.system(size: 15)).foregroundStyle(Theme.ink).lineLimit(1)
                        Text(sub).font(.system(size: 13)).foregroundStyle(Theme.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(tag).font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(fg)
                        .padding(.horizontal, 9).frame(height: 24).background(bg, in: Capsule())
                }
                .padding(.horizontal, 16).padding(.vertical, 9)
            }
            .buttonStyle(.plain).disabled(open == nil)
        }
    }

    private func row(_ title: String, _ sub: String, _ tag: String, _ bg: Color, _ fg: Color,
                     _ photo: Data?, _ symbol: String?, _ open: @escaping () -> Void) -> some View {
        row(title, sub, tag, bg, fg, photo, symbol, Optional(open))
    }
}

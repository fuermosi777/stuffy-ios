import SwiftUI
import SwiftData

/// Wishlist items the user declined, newest first. Restore puts them back on hold.
struct DeclinedListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WishlistItem.decidedDate, order: .reverse) private var all: [WishlistItem]
    @State private var editing: WishlistItem?

    private var declined: [WishlistItem] { all.filter { $0.status == .declined } }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Saved by waiting").foregroundStyle(Theme.secondary)
                    Spacer()
                    Text(money(declined.reduce(0) { $0 + $1.price })).font(.system(size: 20, weight: .bold)).monospacedDigit()
                        .foregroundStyle(Theme.sageFg)
                }
            }
            if declined.isEmpty {
                ContentUnavailableView("Nothing declined yet", systemImage: "hand.raised",
                                       description: Text("Items you decline after waiting show up here."))
            }
            ForEach(declined) { w in
                Button { editing = w } label: { row(w) }
                    .swipeActions(edge: .leading) {
                        Button { restore(w) } label: { Label("Restore", systemImage: "arrow.uturn.backward") }.tint(Theme.accent)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { context.delete(w) } label: { Label("Delete", systemImage: "trash") }
                    }
                    .contextMenu {
                        Button { restore(w) } label: { Label("Move back to wishlist", systemImage: "arrow.uturn.backward") }
                        Button("Delete", role: .destructive) { context.delete(w) }
                    }
            }
        }
        .navigationTitle("Declined")
        .sheet(item: $editing) { WishFormView(wish: $0) }
    }

    private func row(_ w: WishlistItem) -> some View {
        HStack(spacing: 12) {
            PhotoThumb(data: w.photoData, symbol: w.category?.symbol ?? "photo", size: 48, radius: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(w.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(2)
                if let d = w.decidedDate {
                    Text("Declined \(d.formatted(.dateTime.month(.abbreviated).day().year())) · waited \(Item.days(from: w.addedDate, to: d)) days")
                        .font(.system(size: 13)).foregroundStyle(Theme.secondary)
                }
            }
            Spacer()
            Text(money(w.price)).font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.secondary)
        }
    }

    private func restore(_ w: WishlistItem) {
        w.status = .waiting
        w.decidedDate = nil
    }
}

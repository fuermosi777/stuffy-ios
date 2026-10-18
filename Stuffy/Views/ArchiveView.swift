import SwiftUI
import SwiftData

/// Retired and sold items.
struct ArchiveView: View {
    @Query(sort: \Item.endedDate, order: .reverse) private var all: [Item]
    @State private var selected: Item?

    private var ended: [Item] { all.filter { !$0.isActive } }

    var body: some View {
        List {
            if ended.isEmpty {
                ContentUnavailableView("Nothing archived", systemImage: "archivebox",
                                       description: Text("Retired and sold items show up here."))
            }
            ForEach(ended) { item in
                Button { selected = item } label: {
                    HStack(spacing: 12) {
                        PhotoThumb(data: item.photoData, symbol: item.category?.symbol ?? "photo", size: 48, radius: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                            Text(item.status == .sold ? "Sold for \(money(item.resalePrice))" : "Retired")
                                .font(.system(size: 13)).foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        Text("\(fmt(item.costPerUse))/wear").font(.system(size: 14, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(item.tone.foreground)
                    }
                }
            }
        }
        .navigationTitle("Archive")
        .sheet(item: $selected) { ItemDetailView(item: $0) }
    }
}

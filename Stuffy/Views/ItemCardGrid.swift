import SwiftUI

private let thumbCache = NSCache<NSNumber, UIImage>()

/// Decoded, downsampled photo; decoding the full 1200px JPEG on every scroll frame is too slow for a grid.
func cardImage(_ data: Data?) -> UIImage? {
    guard let data else { return nil }
    let key = NSNumber(value: data.hashValue)
    if let hit = thumbCache.object(forKey: key) { return hit }
    guard let img = UIImage(data: data) else { return nil }
    let scale = min(1, 600 / max(img.size.width, img.size.height))
    let target = CGSize(width: img.size.width * scale, height: img.size.height * scale)
    let out = img.preparingThumbnail(of: target) ?? img
    thumbCache.setObject(out, forKey: key)
    return out
}

/// Height / width of the card photo, clamped so extreme panoramas and slivers don't wreck the grid.
private func photoRatio(_ item: Item) -> CGFloat {
    guard let img = cardImage(item.photoData), img.size.width > 0 else { return 1 }
    return min(1.35, max(0.8, img.size.height / img.size.width))
}

/// Two-column waterfall: each item goes to whichever column is currently shorter.
struct ItemWaterfall: View {
    let items: [Item]
    var onOpen: (Item) -> Void
    var onLog: (Item) -> Void
    var onDuplicate: (Item) -> Void
    var onToggleDaily: (Item) -> Void

    private var columns: [[Item]] {
        var cols: [[Item]] = [[], []]
        var heights: [CGFloat] = [0, 0]
        for item in items {
            let i = heights[0] <= heights[1] ? 0 : 1
            cols[i].append(item)
            heights[i] += photoRatio(item) + 0.55 // text block, in card-width units
        }
        return cols
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                LazyVStack(spacing: 12) {
                    ForEach(col) { item in
                        ItemCard(item: item, onOpen: { onOpen(item) }, onLog: { onLog(item) })
                            .contextMenu {
                                Button { onDuplicate(item) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                DailyDriverMenuButton(item: item) { onToggleDaily(item) }
                            }
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 20)
    }
}

struct ItemCard: View {
    let item: Item
    var onOpen: () -> Void
    var onLog: () -> Void
    @State private var bump = false

    private var today: Int { item.wearsToday() }
    private var done: Bool { bump || today > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpen) {
                Color.clear
                    .aspectRatio(1 / photoRatio(item), contentMode: .fit)
                    .overlay {
                        if let img = cardImage(item.photoData) {
                            Image(uiImage: img).resizable().scaledToFill()
                        } else {
                            ZStack {
                                Theme.chip
                                SymbolIcon(name: item.category?.symbol ?? "photo")
                                    .font(.system(size: 34)).foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                    .clipped()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(alignment: .bottom, spacing: 6) {
                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.brand.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.4)
                            .foregroundStyle(Theme.secondary).lineLimit(1)
                        Text(item.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Pill(text: "\(fmt(item.costPerUse))/wear", background: item.tone.background, foreground: item.tone.foreground)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    onLog()
                    withAnimation(.spring(duration: 0.35, bounce: 0.5)) { bump = true }
                    Task { try? await Task.sleep(for: .milliseconds(700)); withAnimation { bump = false } }
                } label: {
                    Group {
                        if today > 1 {
                            Text("\(today)").font(.system(size: 14, weight: .bold)).monospacedDigit()
                        } else {
                            Image(systemName: done ? "checkmark" : "plus").font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundStyle(done ? Theme.sageFg : Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(done ? Theme.sageBg : Color(hex: 0xF2F0EB), in: Circle())
                }
                .accessibilityLabel(today > 0 ? "Worn \(today) today. Log another wear" : "Log a wear")
            }
            .padding(10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Long-press action: mark as, or unmark, its category's daily driver. Hidden for uncategorized items.
struct DailyDriverMenuButton: View {
    let item: Item
    var action: () -> Void

    var body: some View {
        if item.category != nil {
            Button(action: action) {
                if item.dailyOf != nil {
                    Label("Unmark daily driver", systemImage: "sun.max")
                } else {
                    Label("Mark as daily driver", systemImage: "sun.max.fill")
                }
            }
        }
    }
}

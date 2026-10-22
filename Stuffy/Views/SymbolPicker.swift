import SwiftUI

/// A category icon: an SF Symbol name, or an emoji for things SF Symbols has no glyph for (trousers, socks…).
struct SymbolIcon: View {
    var name: String

    var body: some View {
        if UIImage(systemName: name) != nil { Image(systemName: name) } else { Text(name) }
    }
}

struct SymbolPickerSheet: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var emoji = ""

    private static let groups: [(title: String, symbols: [String])] = [
        ("Wear", ["eyeglasses", "sunglasses", "watch.analog", "applewatch", "crown", "diamond", "hat.cap", "hat.widebrim",
                  "hanger", "tshirt", "tshirt.fill", "figure.stand", "figure.dress.line.vertical.figure", "shoe", "shoe.2"]),
        ("Bags & carry", ["bag", "handbag", "backpack", "suitcase.rolling", "briefcase", "wallet.pass", "creditcard", "key", "umbrella"]),
        ("Tech", ["laptopcomputer", "desktopcomputer", "display", "iphone", "ipad", "headphones", "airpodspro",
                  "camera", "gamecontroller", "keyboard", "tv", "speaker.wave.2", "printer", "airtag"]),
        ("Beauty & care", ["sparkles", "comb", "paintbrush", "paintpalette", "drop", "eyedropper", "pill", "cross.case",
                           "scissors", "hands.sparkles", "wand.and.stars"]),
        ("Home", ["house", "lamp.table", "sofa", "bed.double", "refrigerator", "washer", "oven", "cup.and.saucer", "mug",
                  "fork.knife", "basket", "wrench.and.screwdriver", "hammer"]),
        ("Hobbies & more", ["bicycle", "figure.run", "figure.hiking", "dumbbell", "soccerball", "basketball", "tennisball", "tent",
                            "guitars", "music.note", "book", "books.vertical", "film", "theatermasks", "gift", "car",
                            "pawprint", "leaf", "tag", "shippingbox"]),
    ]

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emoji").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary).textCase(.uppercase)
                        HStack {
                            TextField("Type an emoji, e.g. 👖", text: $emoji)
                                .onChange(of: emoji) { _, new in
                                    // Keep only the last emoji typed.
                                    guard let last = new.last(where: Self.isEmoji) else { emoji = ""; return }
                                    emoji = String(last)
                                    selection = String(last)
                                }
                            if !emoji.isEmpty { Text(emoji).font(.system(size: 24)) }
                        }
                        .padding(12).background(Theme.chip, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    ForEach(Self.groups, id: \.title) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary).textCase(.uppercase)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(group.symbols, id: \.self) { name in
                                    Button { selection = name; dismiss() } label: {
                                        Image(systemName: name).font(.system(size: 22))
                                            .frame(width: 52, height: 52)
                                            .foregroundStyle(selection == name ? Theme.background : Theme.ink)
                                            .background(selection == name ? Theme.ink : Theme.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(name)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Icon").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private static func isEmoji(_ c: Character) -> Bool {
        guard let s = c.unicodeScalars.first else { return false }
        return s.properties.isEmoji && s.value > 0x2000
    }
}

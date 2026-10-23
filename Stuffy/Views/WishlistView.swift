import SwiftUI
import SwiftData

struct WishlistView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WishlistItem.addedDate) private var all: [WishlistItem]
    @Query private var items: [Item]
    @AppStorage("holdDays") private var holdDays = 14
    @AppStorage("defaultTarget") private var defaultTarget = 2.0
    @AppStorage("smartGuard") private var smartGuard = true
    @State private var showingAdd = false
    @State private var editing: WishlistItem?
    @State private var toast: Toast?

    private var waiting: [WishlistItem] {
        all.filter { $0.status == .waiting }
            .sorted { ($0.daysLeft(default: holdDays) == 0 ? 0 : 1) < ($1.daysLeft(default: holdDays) == 0 ? 0 : 1) }
    }
    private var saved: Double { all.filter { $0.status == .declined }.reduce(0) { $0 + $1.price } }
    private var declined: Int { all.filter { $0.status == .declined }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    savedCard
                    if waiting.isEmpty {
                        ContentUnavailableView("Nothing on hold", systemImage: "hourglass",
                                               description: Text("Add what you want to buy. Wait out the hold, then decide."))
                            .padding(.top, 40)
                    }
                    ForEach(waiting) { wish in card(wish) }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Wishlist")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus") } }
            }
            .sheet(isPresented: $showingAdd) { WishFormView() }
            .sheet(item: $editing) { WishFormView(wish: $0) }
            .toast($toast)
        }
    }

    private var savedCard: some View {
        NavigationLink { DeclinedListView() } label: { savedCardContent }
            .buttonStyle(.plain)
    }

    private var savedCardContent: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved by waiting").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary)
                    Text(money(saved)).font(.system(size: 30, weight: .bold)).monospacedDigit().foregroundStyle(Theme.sageFg)
                }
                Spacer()
                Text("\(declined) declined · \(all.filter { $0.status == .bought }.count) bought")
                    .font(.system(size: 13)).foregroundStyle(Theme.secondary)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary)
            }
            .padding(16)
        }
    }

    private func card(_ w: WishlistItem) -> some View {
        let total = w.holdDays(default: holdDays), left = w.daysLeft(default: holdDays), ready = left == 0
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Button { editing = w } label: {
                        HStack(spacing: 14) {
                            PhotoThumb(data: w.photoData, symbol: w.category?.symbol ?? "photo", size: 64)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(w.brand.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.4).foregroundStyle(Theme.secondary)
                                Text(w.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(2)
                                Text(money(w.price)).font(.system(size: 15)).monospacedDigit().foregroundStyle(Theme.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit")
                    ring(progress: Double(total - left) / Double(total), left: left, ready: ready)
                }
                Label(ready ? "Hold complete · still want it?" : "\(left) days left of \(total)-day hold",
                      systemImage: ready ? "checkmark" : "hourglass")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 10).frame(height: 28)
                    .foregroundStyle(ready ? Theme.sageFg : Color(hex: 0x55524C))
                    .background(ready ? Color(hex: 0xE7EEE3) : Color(hex: 0xF0EEE9), in: Capsule())
                if smartGuard, let g = guardMessage(for: w) {
                    Label(g.text, systemImage: g.symbol)
                        .font(.system(size: 14)).foregroundStyle(g.fg)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(g.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                HStack(spacing: 10) {
                    Button { decline(w) } label: {
                        Text("Decline").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity).frame(height: 44).background(Theme.chip, in: Capsule())
                    }
                    Button { buy(w) } label: {
                        Text("Bought it").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 44).background(Theme.accent, in: Capsule())
                    }
                }
            }
            .padding(16)
        }
        .contextMenu {
            Button { editing = w } label: { Label("Edit", systemImage: "pencil") }
            Button("Delete", role: .destructive) { context.delete(w) }
        }
    }

    private func ring(progress: Double, left: Int, ready: Bool) -> some View {
        ZStack {
            Circle().stroke(Theme.chip, lineWidth: 5)
            Circle().trim(from: 0, to: progress).stroke(ready ? Color(hex: 0x6E8B6A) : Theme.accent, style: .init(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(ready ? "✓" : "\(left)").font(.system(size: 17, weight: .bold)).monospacedDigit()
                Text(ready ? "ready" : "days").font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.secondary)
            }
        }
        .frame(width: 52, height: 52)
    }

    /// Compares a wish against what's already owned in the same category.
    private func guardMessage(for w: WishlistItem) -> (text: String, symbol: String, bg: Color, fg: Color)? {
        let owned = items.filter { $0.isActive && $0.category != nil && $0.category == w.category }
        if let idle = owned.filter({ $0.idleDays() >= 45 }).max(by: { $0.idleDays() < $1.idleDays() }) {
            return ("Your \(idle.title) has sat idle for \(idle.idleDays()) days at \(fmt(idle.costPerUse))/wear. Are you sure?",
                    "exclamationmark.shield", Theme.amberBg, Theme.amberFg)
        }
        if !owned.isEmpty {
            let avg = owned.reduce(0) { $0 + $1.costPerUse } / Double(owned.count)
            return ("You already own \(owned.count) in \(w.category?.name ?? "this category") with an average \(fmt(avg))/wear. Are you sure?",
                    "exclamationmark.shield", Theme.amberBg, Theme.amberFg)
        }
        return ("Nothing like this in your inventory — it fills a real gap.", "checkmark.shield", Theme.sageBg, Theme.sageFg)
    }

    private func decline(_ w: WishlistItem) {
        w.status = .declined
        w.decidedDate = Date()
        toast = Toast(title: "Saved \(money(w.price))", subtitle: "Declined \(w.name) · nice restraint",
                      actionTitle: "Undo") {
            w.status = .waiting
            w.decidedDate = nil
        }
    }

    private func buy(_ w: WishlistItem) {
        w.status = .bought
        w.decidedDate = Date()
        let item = Item(brand: w.brand, name: w.name, price: w.price, targetCostPerUse: defaultTarget,
                        category: w.category, photoData: w.photoData)
        context.insert(item)
        context.insert(UsageLog(item: item))
        toast = Toast(title: "Added to Items", subtitle: "\(w.name) · first wear logged")
    }
}

/// Adds a wish, or edits `wish` when given. Editing keeps the hold-period start date.
struct WishFormView: View {
    var wish: WishlistItem?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var photo: Data?
    @State private var brand: String
    @State private var name: String
    @State private var priceText: String
    @State private var category: Category?

    init(wish: WishlistItem? = nil) {
        self.wish = wish
        _photo = State(initialValue: wish?.photoData)
        _brand = State(initialValue: wish?.brand ?? "")
        _name = State(initialValue: wish?.name ?? "")
        _priceText = State(initialValue: wish.map { $0.price == $0.price.rounded() ? String(Int($0.price)) : String(format: "%.2f", $0.price) } ?? "")
        _category = State(initialValue: wish?.category)
    }

    private var price: Double { Double(priceText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section { PhotoPickerField(data: $photo).listRowInsets(.init()) }.listRowBackground(Color.clear)
                Section("Details") {
                    HStack { Text("Brand"); TextField("Brand", text: $brand).multilineTextAlignment(.trailing) }
                    HStack { Text("Name"); TextField("Name", text: $name).multilineTextAlignment(.trailing) }
                    HStack { Text("Price"); Spacer(); Text("$").foregroundStyle(Theme.secondary)
                        TextField("0.00", text: $priceText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110) }
                }
                Section("Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories) { c in CategoryChip(label: c.name, selected: category == c) { category = c } }
                        }
                    }
                    .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .scrollContentBackground(.hidden).background(Theme.grouped)
            .navigationTitle(wish == nil ? "New Wish" : "Edit Wish").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(wish == nil ? "Add" : "Save") {
                        let brand = brand.trimmingCharacters(in: .whitespaces), name = name.trimmingCharacters(in: .whitespaces)
                        if let wish {
                            wish.brand = brand; wish.name = name; wish.price = price
                            wish.category = category; wish.photoData = photo
                        } else {
                            context.insert(WishlistItem(brand: brand, name: name, price: price, category: category, photoData: photo))
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || price <= 0).fontWeight(.semibold)
                }
            }
            .onAppear { if wish == nil { category = category ?? categories.first } }
        }
    }
}

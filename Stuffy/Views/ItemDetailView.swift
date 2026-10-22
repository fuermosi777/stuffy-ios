import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Bindable var item: Item
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingEdit = false
    @State private var showingSell = false
    @State private var confirmRetire = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        statsGrid
                        progressCard
                        if item.isActive { logButton; dailyCard } else { endedBanner }
                        metaCard
                        notesCard
                        historyCard
                    }
                    .padding(16)
                }
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { menu }
            }
            .sheet(isPresented: $showingEdit) { ItemFormView(item: item) }
            .sheet(isPresented: $showingSell) { SellSheet(item: item) { dismiss() } }
            .confirmationDialog("Retire \(item.name)?", isPresented: $confirmRetire, titleVisibility: .visible) {
                Button("Retire") { end(.retired) }
            } message: {
                Text("\(item.name) leaves your inventory with a final cost per wear of \(fmt(item.costPerUse)).")
            }
            .confirmationDialog("Delete \(item.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { context.delete(item); dismiss() }
            } message: { Text("This also removes its wear history.") }
        }
    }

    // MARK: Sections

    private var hero: some View {
        // Size comes from the clear base, so a wide photo can't push the layout wider than the screen.
        edgeColor(of: item.photoData)
            .frame(height: 260).frame(maxWidth: .infinity)
            .overlay {
                if let d = item.photoData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFit()
                } else {
                    SymbolIcon(name: item.category?.symbol ?? "photo").font(.system(size: 54)).foregroundStyle(Theme.secondary)
                }
            }
            .clipped()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.brand.uppercased()).font(.system(size: 12, weight: .semibold)).tracking(0.5).foregroundStyle(Theme.secondary)
            Text(item.name).font(.system(size: 26, weight: .bold))
            HStack(spacing: 8) {
                Text("\(fmt(item.costPerUse))/wear").font(.system(size: 17, weight: .semibold)).monospacedDigit()
                Pill(text: item.tone.label, background: item.tone.background, foreground: item.tone.foreground)
            }
            .padding(.top, 4)
        }
    }

    private var statsGrid: some View {
        Card {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    stat("Cost / wear", fmt(item.costPerUse))
                    stat("Cost / day", fmt(item.costPerDay()), leading: true)
                }
                Divider()
                GridRow {
                    stat("Wears", "\(item.uses)")
                    stat("Days owned", "\(item.daysOwned())", leading: true)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, leading: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.secondary)
            Text(value).font(.system(size: 22, weight: .bold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(alignment: .leading) { if leading { Rectangle().fill(Color.black.opacity(0.08)).frame(width: 0.5) } }
    }

    private var progressCard: some View {
        let target = item.targetCostPerUse
        let need = item.usesNeeded(for: target)
        let remaining = max(0, need - item.uses)
        let weeks = Double(item.uses) / max(1, Double(item.daysOwned()) / 7)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Progress to \(fmt(target))/wear").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("\(item.uses) / \(need)").font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.secondary)
                }
                ProgressView(value: min(1, Double(item.uses) / Double(max(1, need)))).tint(item.tone.bar)
                HStack {
                    ForEach([4.0, 2.0, 1.0], id: \.self) { k in
                        let w = item.usesNeeded(for: target * k)
                        VStack(spacing: 1) {
                            Text(fmt(target * k)).font(.system(size: 12, weight: .semibold))
                            Text("\(w) wears").font(.system(size: 11))
                        }
                        .foregroundStyle(item.uses >= w ? Theme.sageFg : Theme.secondary)
                        .frame(maxWidth: .infinity)
                    }
                }
                Text(remaining > 0 ? "\(remaining) more wears to reach \(fmt(target))/wear." : "Target reached — this one has paid for itself.")
                    .font(.system(size: 14))
                if remaining > 0 {
                    Text(weeks > 0.2 ? "At ~\(String(format: "%.1f", weeks))×/week, about \(Int((Double(remaining) / weeks).rounded(.up))) weeks." : "Wear it more often to get there.")
                        .font(.system(size: 13)).foregroundStyle(Theme.secondary)
                }
            }
            .padding(16)
        }
    }

    private var logButton: some View {
        Button {
            item.logWear(in: context)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Label("Log a wear", systemImage: "plus").font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity).frame(height: 52)
                .foregroundStyle(.white).background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder private var dailyCard: some View {
        if let category = item.category {
            let isDriver = item.dailyOf != nil
            Card {
                Toggle(isOn: Binding(
                    get: { item.dailyOf != nil },
                    set: { on in
                        if on { DailyDriver.assign(item, in: context) } else { DailyDriver.clear(item) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Daily driver", systemImage: "sun.max.fill").font(.system(size: 15, weight: .semibold))
                        Text(isDriver ? "Counts a wear every day. Switch or turn off anytime."
                             : category.dailyItem.map { "Replaces \($0.name) as the daily driver for \(category.name)." }
                                ?? "Count a wear every day automatically, with nothing to log.")
                            .font(.system(size: 13)).foregroundStyle(Theme.secondary)
                    }
                }
                .padding(16)
            }
        }
    }

    private var endedBanner: some View {
        let sold = item.status == .sold
        return HStack(spacing: 10) {
            Image(systemName: sold ? "arrow.3.trianglepath" : "archivebox")
            VStack(alignment: .leading, spacing: 2) {
                Text(sold ? "Sold for \(money(item.resalePrice))" : "Retired").font(.system(size: 15, weight: .semibold))
                Text(sold ? "Recovered \(money(item.resalePrice)) of \(money(item.price))." : "No longer in your inventory.").font(.system(size: 13))
            }
            Spacer()
            Button("Restore") { restore() }.font(.system(size: 15, weight: .semibold))
        }
        .padding(14).foregroundStyle(Theme.sageFg)
        .background(Theme.sageBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var metaCard: some View {
        Card {
            VStack(spacing: 0) {
                metaRow("Purchased", item.purchaseDate.formatted(date: .abbreviated, time: .omitted))
                Divider()
                metaRow("Paid", fmt(item.price))
                if item.status == .sold { Divider(); metaRow("Sold for", fmt(item.resalePrice)) }
                Divider()
                metaRow("Category", item.category?.name ?? "—")
                Divider()
                metaRow("Last worn", item.lastUsed == nil ? "Not yet" : lastUsedText(Item.days(from: item.lastUsed!, to: Date())))
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private var notesCard: some View {
        if !item.notes.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary)
                    Text(item.notes).font(.system(size: 15))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
    }

    private func metaRow(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(Theme.secondary); Spacer(); Text(v) }
            .font(.system(size: 15)).padding(.vertical, 12)
    }

    @ViewBuilder private var historyCard: some View {
        let logs = item.sortedLogs
        if !logs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("History").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary).textCase(.uppercase)
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(logs.prefix(20).enumerated()), id: \.element.persistentModelID) { i, log in
                            if i > 0 { Divider() }
                            HStack {
                                Text(log.date.formatted(log.isAuto ? .dateTime.month(.abbreviated).day().year() : .dateTime.month(.abbreviated).day().year().hour().minute()))
                                    .font(.system(size: 15))
                                if log.isAuto { Pill(text: "Daily", background: Theme.chip, foreground: Theme.secondary) }
                                Spacer()
                                Button(role: .destructive) { context.delete(log) } label: { Image(systemName: "minus.circle") }
                                    .accessibilityLabel("Delete this wear")
                            }
                            .padding(.vertical, 11)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var menu: some View {
        Menu {
            Button { showingEdit = true } label: { Label("Edit", systemImage: "pencil") }
            if item.isActive {
                Button { showingSell = true } label: { Label("Mark as sold", systemImage: "arrow.3.trianglepath") }
                Button { confirmRetire = true } label: { Label("Retire", systemImage: "archivebox") }
            } else {
                Button { restore() } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
            }
            Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
        } label: { Image(systemName: "ellipsis.circle") }
    }

    private func end(_ status: ItemStatus) {
        DailyDriver.clear(item)
        item.status = status
        item.endedDate = Date()
        dismiss()
    }

    private func restore() {
        item.status = .active
        item.endedDate = nil
        item.resalePrice = 0
    }
}

/// Records what an item sold for; the net cost drops accordingly.
struct SellSheet: View {
    @Bindable var item: Item
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var priceText = ""
    @State private var date = Date()

    private var resale: Double { Double(priceText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Sold for"); Spacer()
                        Text("$").foregroundStyle(Theme.secondary)
                        TextField("0.00", text: $priceText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110)
                    }
                    DatePicker("Date", selection: $date, in: item.purchaseDate...Date(), displayedComponents: .date)
                } footer: {
                    Text("You paid \(fmt(item.price)). Net cost becomes \(fmt(max(0, item.price - resale))), or \(fmt(max(0, item.price - resale) / Double(max(1, item.uses))))/wear.")
                }
            }
            .navigationTitle("Mark as sold").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        DailyDriver.clear(item)
                        item.resalePrice = resale
                        item.endedDate = date
                        item.status = .sold
                        dismiss(); onDone()
                    }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

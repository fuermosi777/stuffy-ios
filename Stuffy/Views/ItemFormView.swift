import SwiftUI
import SwiftData

/// Add (item == nil) or edit an item.
struct ItemFormView: View {
    let item: Item?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @AppStorage("defaultTarget") private var defaultTarget = 2.0

    @State private var photo: Data?
    @State private var brand = ""
    @State private var name = ""
    @State private var category: Category?
    @State private var priceText = ""
    @State private var date = Date()
    @State private var usedSoFar = 0
    @State private var target = 2.0
    @State private var loaded = false

    private var price: Double { Double(priceText) ?? 0 }
    private var canSave: Bool { !brand.trimmingCharacters(in: .whitespaces).isEmpty && !name.trimmingCharacters(in: .whitespaces).isEmpty && price > 0 }
    private var daysOwned: Int { max(1, Item.days(from: date, to: Date())) }

    var body: some View {
        NavigationStack {
            Form {
                Section { PhotoPickerField(data: $photo).listRowInsets(.init()) }
                    .listRowBackground(Color.clear)

                Section("Details") {
                    field("Brand", text: $brand)
                    field("Name", text: $name)
                }

                Section("Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories) { c in
                                CategoryChip(label: c.name, selected: category == c) { category = c }
                            }
                        }
                    }
                    .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Purchase") {
                    HStack {
                        Text("Price")
                        Spacer()
                        Text("$").foregroundStyle(Theme.secondary)
                        TextField("0.00", text: $priceText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110)
                    }
                    DatePicker("Purchased", selection: $date, in: ...Date(), displayedComponents: .date)
                }

                Section("Usage") {
                    Stepper(value: $usedSoFar, in: 0...100_000) {
                        HStack { Text("Used so far"); Spacer(); Text("\(usedSoFar) \(usedSoFar == 1 ? "wear" : "wears")").foregroundStyle(Theme.secondary) }
                    }
                    Stepper(value: $target, in: 0.5...20, step: 0.5) {
                        HStack { Text("Target"); Spacer(); Text("\(fmt(target))/wear").foregroundStyle(Theme.secondary) }
                    }
                }

                Section {
                    HStack {
                        stat("Cost / wear", price > 0 ? fmt(price / Double(max(1, usedSoFar))) : "—")
                        Divider()
                        stat("Cost / day", price > 0 ? fmt(price / Double(daysOwned)) : "—")
                    }
                } header: { Text("Live estimate") } footer: {
                    Text(price > 0 ? "Based on \(daysOwned) \(daysOwned == 1 ? "day" : "days") owned. Both numbers drop as you log wears and keep it longer." : "Enter a price to see cost per wear and per day.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.grouped)
            .navigationTitle(item == nil ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(item == nil ? "Add" : "Save", action: save).disabled(!canSave).fontWeight(.semibold) }
            }
            .onAppear(perform: load)
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            TextField(label, text: text).multilineTextAlignment(.trailing)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.secondary)
            Text(value).font(.system(size: 24, weight: .bold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        target = defaultTarget
        category = categories.first
        guard let item else { return }
        photo = item.photoData
        brand = item.brand
        name = item.name
        category = item.category
        priceText = item.price.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
        date = item.purchaseDate
        usedSoFar = item.initialUses
        target = item.targetCostPerUse
    }

    private func save() {
        let b = brand.trimmingCharacters(in: .whitespaces), n = name.trimmingCharacters(in: .whitespaces)
        if let item {
            item.brand = b; item.name = n; item.price = price; item.purchaseDate = date
            item.initialUses = usedSoFar; item.targetCostPerUse = target
            item.category = category; item.photoData = photo
        } else {
            context.insert(Item(brand: b, name: n, price: price, purchaseDate: date, targetCostPerUse: target,
                                initialUses: usedSoFar, category: category, photoData: photo))
        }
        dismiss()
    }
}

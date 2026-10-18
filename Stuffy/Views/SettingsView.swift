import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Query private var items: [Item]
    @Query(filter: #Predicate<WishlistItem> { $0.statusRaw == "declined" }) private var declined: [WishlistItem]
    @AppStorage("holdDays") private var holdDays = 14
    @AppStorage("defaultTarget") private var defaultTarget = 2.0
    @AppStorage("idleDays") private var idleDays = 45
    @AppStorage("smartGuard") private var smartGuard = true
    @AppStorage("dailyReminder") private var dailyReminder = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "shippingbox.fill").foregroundStyle(.white).frame(width: 44, height: 44)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading) {
                            Text("Your stuff").font(.headline)
                            Text("\(items.filter(\.isActive).count) items · saved \(money(declined.reduce(0) { $0 + $1.price })) by waiting")
                                .font(.subheadline).foregroundStyle(Theme.secondary)
                        }
                    }
                }

                Section("Before you buy") {
                    Picker("Hold period", selection: $holdDays) {
                        ForEach([7, 14, 30], id: \.self) { Text("\($0) days").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle(isOn: $smartGuard) {
                        VStack(alignment: .leading) { Text("Smart Guard"); Text("Warn when I already own similar items").font(.caption).foregroundStyle(Theme.secondary) }
                    }
                }

                Section("Targets") {
                    Stepper(value: $defaultTarget, in: 0.5...20, step: 0.5) {
                        HStack { Text("Target"); Spacer(); Text("\(fmt(defaultTarget))/wear").foregroundStyle(Theme.secondary) }
                    }
                    Stepper(value: $idleDays, in: 14...365, step: 7) {
                        HStack { Text("Idle after"); Spacer(); Text("\(idleDays) days").foregroundStyle(Theme.secondary) }
                    }
                }

                Section("Reminders") {
                    Toggle(isOn: $dailyReminder) {
                        VStack(alignment: .leading) { Text("Daily log reminder"); Text("8:00 PM").font(.caption).foregroundStyle(Theme.secondary) }
                    }
                    .onChange(of: dailyReminder) { _, on in Reminders.set(enabled: on) { if !$0 { dailyReminder = false } } }
                }

                Section("Library") {
                    NavigationLink("Categories") { CategoriesView() }
                    NavigationLink("Archive") { ArchiveView() }
                    ShareLink(item: csvURL()) { Label("Export CSV", systemImage: "square.and.arrow.up") }
                }
            }
            .scrollContentBackground(.hidden).background(Theme.grouped)
            .navigationTitle("Settings")
        }
    }

    private func csvURL() -> URL {
        var rows = ["brand,name,category,status,price,resale,purchased,wears,cost_per_wear"]
        for i in items {
            let f = [i.brand, i.name, i.category?.name ?? "", i.status.rawValue, "\(i.price)", "\(i.resalePrice)",
                     i.purchaseDate.formatted(.iso8601.year().month().day()), "\(i.uses)", String(format: "%.2f", i.costPerUse)]
            rows.append(f.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stuffy-inventory.csv")
        try? rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

enum Reminders {
    private static let id = "daily-log"

    static func set(enabled: Bool, completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        guard enabled else { center.removePendingNotificationRequests(withIdentifiers: [id]); return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Wear anything new today?"
            content.body = "One tap to log it in Stuffy."
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 20), repeats: true)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var newName = ""
    @State private var pendingDelete: Category?

    var body: some View {
        List {
            Section {
                ForEach(categories) { c in
                    HStack {
                        Image(systemName: c.symbol).frame(width: 28).foregroundStyle(Theme.secondary)
                        TextField("Name", text: Bindable(c).name)
                        Text("\(c.items?.count ?? 0)").foregroundStyle(Theme.secondary).monospacedDigit()
                    }
                }
                .onDelete { offsets in
                    // Deleting a category in use would orphan its items; confirm first.
                    guard let i = offsets.first else { return }
                    let c = categories[i]
                    if (c.items?.isEmpty ?? true) && (c.wishes?.isEmpty ?? true) { delete(c) } else { pendingDelete = c }
                }
                .onMove { from, to in
                    var list = categories
                    list.move(fromOffsets: from, toOffset: to)
                    for (i, c) in list.enumerated() { c.sortOrder = i }
                }
            }
            Section("Add category") {
                HStack {
                    TextField("e.g. Cosmetics", text: $newName).onSubmit(add)
                    Button("Add", action: add).disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar { EditButton() }
        .confirmationDialog("Delete \(pendingDelete?.name ?? "")?", isPresented: .constant(pendingDelete != nil), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let c = pendingDelete { delete(c) }; pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { Text("Its items stay in your inventory without a category.") }
    }

    private func add() {
        let n = newName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        context.insert(Category(name: n, symbol: "tag", sortOrder: (categories.map(\.sortOrder).max() ?? -1) + 1))
        newName = ""
    }

    private func delete(_ c: Category) { context.delete(c) }
}

import Foundation
import SwiftData

/// Daily drivers (watch, glasses, a go-to top…) earn one wear per calendar day without logging.
/// A category can have several. Wears are real `UsageLog`s flagged `isAuto`, created when the app opens,
/// so calendar and cost math just work.
enum DailyDriver {
    /// Longest stretch credited in one go, in case the cursor is stale.
    private static let maxBackfillDays = 3660

    /// Makes `item` a daily driver of its category, starting today.
    static func assign(_ item: Item, in context: ModelContext, now: Date = Date()) {
        guard let category = item.category, item.isActive, item.dailyOf == nil else { return }
        let cal = Calendar.current
        // Bring the existing drivers up to date first; the shared cursor then moves past today.
        reconcile(in: context, now: now)
        item.dailyOf = category
        category.dailyCursor = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))
        if !hasWear(item, on: now) { context.insert(UsageLog(date: now, item: item, isAuto: true)) }
    }

    /// Stops crediting; wears already counted stay.
    static func clear(_ item: Item) {
        guard let category = item.dailyOf else { return }
        item.dailyOf = nil
        if !(category.dailyItems ?? []).contains(where: { $0 !== item }) { category.dailyCursor = nil }
    }

    private static func hasWear(_ item: Item, on day: Date) -> Bool {
        (item.logs ?? []).contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    /// Credits missed days, drops drivers that no longer qualify, and removes duplicate auto wears.
    static func reconcile(in context: ModelContext, now: Date = Date()) {
        guard let categories = try? context.fetch(FetchDescriptor<Category>()) else { return }
        let today = Calendar.current.startOfDay(for: now)
        for category in categories {
            for driver in category.dailyItems ?? [] where !driver.isActive || driver.category !== category { clear(driver) }
            let drivers = category.dailyItems ?? []
            if !drivers.isEmpty { credit(drivers, in: category, through: today, now: now, context: context) }
            for item in category.items ?? [] { tidy(item, context: context) }
        }
    }

    private static func credit(_ drivers: [Item], in category: Category, through today: Date, now: Date, context: ModelContext) {
        let cal = Calendar.current
        let oldest = cal.date(byAdding: .day, value: -maxBackfillDays, to: today) ?? today
        var day = max(oldest, category.dailyCursor ?? today)
        while day <= today {
            // Past days sit at noon so they're safe from DST and time zone shifts.
            let date = day == today ? now : (cal.date(byAdding: .hour, value: 12, to: day) ?? day)
            for driver in drivers where !hasWear(driver, on: day) {
                context.insert(UsageLog(date: date, item: driver, isAuto: true))
            }
            day = cal.date(byAdding: .day, value: 1, to: day) ?? today.addingTimeInterval(86_400)
        }
        category.dailyCursor = cal.date(byAdding: .day, value: 1, to: today)
    }

    /// At most one auto wear per item per day, and none on days the user logged that item by hand.
    private static func tidy(_ item: Item, context: ModelContext) {
        let cal = Calendar.current
        let logs = item.logs ?? []
        let manualDays = Set(logs.filter { !$0.isAuto }.map { cal.startOfDay(for: $0.date) })
        var seen = Set<Date>()
        for log in logs where log.isAuto {
            let day = cal.startOfDay(for: log.date)
            if manualDays.contains(day) || !seen.insert(day).inserted { context.delete(log) }
        }
    }
}

extension Item {
    /// Logs a wear now. Returns false when today's wear was already counted by the daily driver,
    /// in which case that log becomes this manual one and the count doesn't change.
    @discardableResult
    func logWear(in context: ModelContext, now: Date = Date()) -> Bool {
        var added = true
        if let auto = logs?.first(where: { $0.isAuto && Calendar.current.isDate($0.date, inSameDayAs: now) }) {
            auto.isAuto = false
            auto.date = now
            added = false
        } else {
            context.insert(UsageLog(date: now, item: self))
        }
        DailyDriver.reconcile(in: context, now: now)
        return added
    }
}

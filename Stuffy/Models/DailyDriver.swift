import Foundation
import SwiftData

/// A category's daily driver (watch, glasses, wallet…) earns one wear per calendar day without logging.
/// Wears are real `UsageLog`s flagged `isAuto`, created when the app opens, so calendar and cost math just work.
enum DailyDriver {
    /// Longest stretch credited in one go, in case the cursor is stale.
    private static let maxBackfillDays = 3660

    /// Makes `item` its category's daily driver, starting today.
    static func assign(_ item: Item, in context: ModelContext, now: Date = Date()) {
        guard let category = item.category, item.isActive, category.dailyItem !== item else { return }
        let cal = Calendar.current
        if let old = category.dailyItem {
            // Today belongs to the new driver.
            for log in old.logs ?? [] where log.isAuto && cal.isDate(log.date, inSameDayAs: now) { context.delete(log) }
        }
        category.dailyItem = item
        category.dailyCursor = cal.startOfDay(for: now)
        reconcile(in: context, now: now)
    }

    /// Stops crediting; wears already counted stay.
    static func clear(_ category: Category) {
        category.dailyItem = nil
        category.dailyCursor = nil
    }

    static func clear(_ item: Item) {
        if let category = item.dailyOf { clear(category) }
    }

    /// Credits missed days, drops drivers that no longer qualify, and removes auto wears that a manual log supersedes.
    static func reconcile(in context: ModelContext, now: Date = Date()) {
        guard let categories = try? context.fetch(FetchDescriptor<Category>()) else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        for category in categories {
            if let driver = category.dailyItem {
                if !driver.isActive || driver.category !== category {
                    clear(category)
                } else {
                    credit(driver, in: category, through: today, now: now, context: context)
                }
            }
            tidy(category, context: context)
        }
    }

    private static func credit(_ driver: Item, in category: Category, through today: Date, now: Date, context: ModelContext) {
        let cal = Calendar.current
        let oldest = cal.date(byAdding: .day, value: -maxBackfillDays, to: today) ?? today
        var day = max(oldest, category.dailyCursor ?? today)
        while day <= today {
            // Past days sit at noon so they're safe from DST and time zone shifts.
            let date = day == today ? now : (cal.date(byAdding: .hour, value: 12, to: day) ?? day)
            context.insert(UsageLog(date: date, item: driver, isAuto: true))
            day = cal.date(byAdding: .day, value: 1, to: day) ?? today.addingTimeInterval(86_400)
        }
        category.dailyCursor = cal.date(byAdding: .day, value: 1, to: today)
    }

    /// One wear per category per day from auto-crediting, and none on days the user logged something by hand.
    private static func tidy(_ category: Category, context: ModelContext) {
        let cal = Calendar.current
        let logs = (category.items ?? []).flatMap { $0.logs ?? [] }
        let manualDays = Set(logs.filter { !$0.isAuto }.map { cal.startOfDay(for: $0.date) })
        let driver = category.dailyItem
        // Current driver first, so a duplicate from another device never outlives it.
        let auto = logs.filter(\.isAuto).sorted { ($0.item === driver ? 0 : 1) < ($1.item === driver ? 0 : 1) }
        var seen = Set<Date>()
        for log in auto {
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

import Foundation

// Calendar's own numbering (1 = Sunday), not Locale.Weekday's: the decision this drives is taken
// inside the monitor extension, where the only thing there is to go on is
// Calendar.component(.weekday, from:). Locale.Weekday is a String enum with no number at all, so
// one side has to carry the mapping, and it is the side both processes read.
enum WakeAlarmWeekday: Int, CaseIterable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var localeWeekday: Locale.Weekday {
        switch self {
        case .sunday: .sunday
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        }
    }
}

extension Collection<WakeAlarmWeekday> {
    // Sorted rather than in set order: what goes into AlarmKit should not depend on hashing, or two
    // identical selections produce two different arrays and nothing that compares them can work.
    var localeWeekdays: [Locale.Weekday] {
        sorted { $0.rawValue < $1.rawValue }.map(\.localeWeekday)
    }
}

// Same App-Group suite and the same injectable-defaults shape as WakeAlarmStore and
// MorningBlockDurationStore. Read from two processes: the app hands the selection to AlarmKit, the
// monitor extension asks it whether today is one of the chosen days.
enum WakeAlarmWeekdayStore {
    static let everyDay: Set<WakeAlarmWeekday> = Set(WakeAlarmWeekday.allCases)

    private static let selectedKey = "wakeAlarmWeekdays"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    // Absent, empty and unreadable all resolve to every day — exactly what every install from
    // before this setting existed already did. Nothing narrows by accident: only a stored subset
    // ever takes a day away.
    nonisolated static func selected(in defaults: UserDefaults = Self.defaults) -> Set<WakeAlarmWeekday> {
        let stored = (defaults.array(forKey: selectedKey) as? [Int] ?? [])
            .compactMap(WakeAlarmWeekday.init(rawValue:))
        return stored.isEmpty ? everyDay : Set(stored)
    }

    nonisolated static func normalized(_ days: Set<WakeAlarmWeekday>) -> Set<WakeAlarmWeekday> {
        days.isEmpty ? everyDay : days
    }

    // An empty selection is refused rather than written: it would be an alarm that never rings and
    // a window that never applies, under a screen that still says an alarm is set — the silent
    // discrepancy this project keeps finding. Switching everything off has its own control
    // ("Wecker ausschalten"), which takes the alarm and the block window with it.
    nonisolated static func store(_ days: Set<WakeAlarmWeekday>, in defaults: UserDefaults = Self.defaults) {
        guard !days.isEmpty else { return }
        defaults.set(days.map(\.rawValue).sorted(), forKey: selectedKey)
    }

    // The gate the monitor extension asks, and the reason this store exists at all:
    // DeviceActivitySchedule has no weekday parameter (repeats: true means every day), so the
    // morning window stays registered on days nobody chose and intervalDidStart fires there too.
    // Without this the weekday selection would only silence the alarm and still block the phone.
    //
    // An unreadable weekday number resolves to true: the days a user chose are the days the shield
    // has always gone up on, and a calendar this build cannot read is no reason to drop a block.
    nonisolated static func morningBlockApplies(
        on date: Date,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) -> Bool {
        guard let weekday = WakeAlarmWeekday(rawValue: calendar.component(.weekday, from: date))
        else { return true }
        return selected(in: defaults).contains(weekday)
    }
}

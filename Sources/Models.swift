import Foundation

enum Mission: String, Codable, CaseIterable, Identifiable {
    case pushups, squats, dance, march, stretch, breathe, sunTaps
    var id: String { rawValue }
    var title: String { switch self { case .pushups: "Push-ups"; case .squats: "Easy squats"; case .dance: "Dance party"; case .march: "Morning march"; case .stretch: "Gentle stretch"; case .breathe: "Slow breaths"; case .sunTaps: "Follow the sun" } }
    var symbol: String { switch self { case .pushups: "figure.strengthtraining.functional"; case .squats: "figure.strengthtraining.traditional"; case .dance: "figure.dance"; case .march: "figure.walk"; case .stretch: "figure.flexibility"; case .breathe: "wind"; case .sunTaps: "hand.tap" } }
    var subtitle: String { switch self { case .pushups: "A little strength. A fresh start."; case .squats: "Lower gently. Rise with the sun."; case .dance: "One tiny party before the day."; case .march: "Small steps to start your day."; case .stretch: "Ease into the morning, seated or standing."; case .breathe: "Take a quiet moment for yourself."; case .sunTaps: "Wake your focus, one sunny tap at a time." } }
    var isCounted: Bool { self == .pushups || self == .squats || self == .sunTaps }
    var supportsMotion: Bool { self == .dance || self == .march }
    var defaultTarget: Int { switch self { case .pushups, .squats: 5; case .sunTaps: 8; default: 30 } }
    var unit: String { self == .sunTaps ? "taps" : isCounted ? "reps" : "seconds" }
    var countingHint: String { switch self { case .pushups: "Self-count or optional camera estimate"; case .squats: "Self-count each comfortable repetition"; case .dance, .march: "Active timer or optional motion estimate"; case .stretch, .breathe: "A gentle active timer"; case .sunTaps: "Tap the highlighted sun eight times" } }
    var instructions: String { switch self {
        case .pushups: "Place your device securely at floor level, facing your side. Keep your whole body in view. Use your knees or a wall if that feels better. Camera counting estimates repetitions; you can always count yourself."
        case .dance: "Make some space and move however you like. For motion counting, hold your phone securely or keep it in a pocket. On iPad, guided mode is more comfortable. No jumping or fast moves needed."
        case .stretch: "Sit comfortably or stand with support. Slowly roll your shoulders, reach gently upward, then relax your arms. Breathe normally and stay within a comfortable range."
        case .squats: "Stand near a stable support, feet comfortably apart. Bend your knees only as far as feels easy, then stand tall. A supported sit-to-stand is fine too. Tap after each repetition; squats use your own count."
        case .march: "March slowly in place beside stable support, or lift one heel at a time while seated. Guided mode uses a timer. Optional phone motion sensing estimates active movement; keep your device secure."
        case .breathe: "Sit comfortably. Follow a gentle rhythm: breathe in for four seconds, out for six. No breath holds. If this pace feels uncomfortable, breathe normally or stop. The timer guides the session; it does not measure breathing."
        case .sunTaps: "Find the highlighted sun and tap it as it moves between four spots. Eight taps make a sunrise. You can do this seated or in bed, without camera or motion access."
    } }
}

struct WakeAlarm: Codable, Identifiable, Equatable {
    var id = UUID()
    var hour = 7
    var minute = 0
    var label = "My morning"
    var weekdays: [Int] = [2,3,4,5,6] // Calendar weekday: Sunday = 1.
    var mission: Mission = .dance
    var target = 30
    var tone = "FirstLight"
    var enabled = true
    var timeText: String {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour, minute: minute)) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
    var repeatText: String {
        if weekdays.isEmpty { return "Once" }
        if Set(weekdays) == Set(1...7) { return "Every day" }
        if Set(weekdays) == Set(2...6) { return "Weekdays" }
        return weekdays.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: " · ")
    }
    func nextFire(after date: Date, calendar: Calendar = .current) -> Date? {
        let days = weekdays.isEmpty ? Array(1...7) : weekdays
        return days.compactMap { day in
            var components = DateComponents()
            if !weekdays.isEmpty { components.weekday = day }
            components.hour = hour; components.minute = minute; components.second = 0
            return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime, repeatedTimePolicy: .first)
        }.min()
    }
}

struct Sunrise: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var alarmID: UUID
    var mission: Mission
    var amount: Int
    var mood: String?
}

enum Journal {
    static func streak(_ records: [Sunrise], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(records.map { calendar.startOfDay(for: $0.date) })
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) { cursor = calendar.date(byAdding: .day, value: -1, to: cursor)! }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}

/// Requires a full extended → lowered → extended cycle with a cooldown.
struct RepCounter {
    private(set) var count = 0
    private var armed = false
    private var lowered = false
    private var lastCount = -Double.infinity
    mutating func consume(angle: Double?, time: TimeInterval) -> Bool {
        guard let angle, angle.isFinite else { armed = false; lowered = false; return false }
        if angle > 150 {
            if armed && lowered && time - lastCount >= 0.9 {
                count += 1; lowered = false; lastCount = time; return true
            }
            armed = true
        } else if angle < 100 && armed { lowered = true }
        return false
    }
}

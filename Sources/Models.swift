import Foundation
import CryptoKit

enum Mission: String, Codable, CaseIterable, Identifiable {
    case pushups, squats, dance, march, stretch, breathe, sunTaps
    case math, memory, words, scanCode, daylight, water
    var id: String { rawValue }
    var title: String { switch self {
        case .pushups: "Push-ups"; case .squats: "Easy squats"; case .dance: "Dance party"
        case .march: "Morning march"; case .stretch: "Gentle stretch"; case .breathe: "Slow breaths"
        case .sunTaps: "Follow the sun"; case .math: "Morning maths"; case .memory: "Sun sequence"
        case .words: "A little intention"; case .scanCode: "Reach my destination"
        case .daylight: "Let in the light"; case .water: "Prepare a drink"
    } }
    var symbol: String { switch self {
        case .pushups: "figure.strengthtraining.functional"; case .squats: "figure.strengthtraining.traditional"
        case .dance: "figure.dance"; case .march: "figure.walk"; case .stretch: "figure.flexibility"
        case .breathe: "wind"; case .sunTaps: "hand.tap"; case .math: "plus.forwardslash.minus"
        case .memory: "square.grid.2x2"; case .words: "text.cursor"; case .scanCode: "qrcode.viewfinder"
        case .daylight: "sun.max"; case .water: "cup.and.saucer"
    } }
    var subtitle: String { switch self {
        case .pushups: "A little strength. A fresh start."; case .squats: "Lower gently. Rise with the sun."
        case .dance: "One tiny party before the day."; case .march: "Small steps to start your day."
        case .stretch: "Ease into the morning, seated or standing."; case .breathe: "Take a quiet moment."
        case .sunTaps: "Wake your focus, one sunny tap at a time."; case .math: "Small sums to bring your focus back."
        case .memory: "Remember a short trail of sunshine."; case .words: "Type a promise to your morning."
        case .scanCode: "Scan a code away from your bed."; case .daylight: "Open a curtain or switch on a light."
        case .water: "A simple action in your kitchen."
    } }
    var isCounted: Bool { [.pushups,.squats,.sunTaps,.math,.memory,.words,.scanCode,.daylight,.water].contains(self) }
    var isTimer: Bool { !isCounted }
    var supportsMotion: Bool { self == .dance || self == .march }
    var defaultTarget: Int { switch self { case .pushups,.squats: 5; case .sunTaps: 8; case .math,.memory: 3; case .words,.scanCode,.daylight,.water: 1; default: 30 } }
    var targetRange: ClosedRange<Int> { switch self { case .words,.scanCode,.daylight,.water: 1...1; case .math,.memory: 1...10; case .sunTaps,.pushups,.squats: 1...30; default: 10...180 } }
    var unit: String { switch self { case .sunTaps: "taps"; case .math: "sums"; case .memory: "rounds"; case .words: "intention"; case .scanCode: "destination"; case .daylight,.water: "action"; case .pushups,.squats: "reps"; default: "seconds" } }
    var countingHint: String { switch self {
        case .pushups: "Self-count or optional camera estimate"; case .squats: "Self-count each comfortable repetition"
        case .dance,.march: "Active timer or optional motion estimate"; case .stretch,.breathe: "A gentle active timer"
        case .sunTaps: "Tap the highlighted sun"; case .math: "Type the correct answer"; case .memory: "Repeat the sun sequence"
        case .words: "Type your intention"; case .scanCode: "Scan your saved code or use an honest check-in"
        case .daylight,.water: "Confirm the action yourself"
    } }
    var instructions: String { switch self {
        case .pushups: "Place your device securely at floor level, facing your side. Keep your whole body in view. Knees or a wall are fine. Camera counting estimates repetitions; you can always count yourself."
        case .squats: "Stand near a stable support. Bend only as far as feels easy, then stand tall. A supported sit-to-stand is fine. Tap after each comfortable repetition."
        case .dance: "Make some space and move however you like. Hold your phone securely or keep it in a pocket for optional motion counting. On iPad, guided mode is more comfortable."
        case .march: "March beside stable support, or lift one heel at a time while seated. Guided mode uses a timer. Optional phone motion sensing estimates active movement."
        case .stretch: "Sit comfortably or stand with support. Roll your shoulders, reach gently upward, then relax. Stay within a comfortable range."
        case .breathe: "Breathe in gently for four seconds, out for six. No breath holds. If this pace is uncomfortable, breathe normally or stop. This is a guide, not a breathing measurement."
        case .sunTaps: "Find and tap the highlighted sun as it moves between four spots. You can do this seated or in bed."
        case .math: "Solve a few small sums at your chosen difficulty. Type the answer; there is no time pressure and mistakes simply let you try again."
        case .memory: "Watch the numbered trail of suns. When it disappears, repeat the same order. You can replay it whenever you need."
        case .words: "Type the intention you chose the night before. Punctuation and letter case do not need to match."
        case .scanCode: "Go to your chosen destination and scan its saved barcode or QR code. Scanning stays on device. If scanning is unavailable, choose an honest manual check-in."
        case .daylight: "Open a curtain or switch on a comfortable light. Confirm when you have done it. The app does not measure room light."
        case .water: "Prepare your usual morning drink, or have a comfortable sip if you want. Confirm the action yourself. You can choose a different step anytime."
    } }
}

struct RitualStep: Codable, Identifiable, Equatable {
    var id = UUID()
    var mission: Mission
    var target: Int
    var difficulty = 1
    var intention = "Today I will start small."
    var destinationID: UUID?
    init(mission: Mission, target: Int? = nil) { self.mission = mission; self.target = target ?? mission.defaultTarget }
}
struct Destination: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var digest: String
    static func hash(_ code: String) -> String { SHA256.hash(data: Data(code.utf8)).map { String(format:"%02x",$0) }.joined() }
}
enum WakeSchedule: String, Codable, CaseIterable, Identifiable {
    case weekly, dated, rotation
    var id: String { rawValue }
    var title: String { switch self { case .weekly: "Weekdays"; case .dated: "A specific date"; case .rotation: "Work / rest cycle" } }
}
struct WakeAlarm: Codable, Identifiable, Equatable {
    var id = UUID()
    var hour = 7, minute = 0
    var label = "My morning"
    var weekdays: [Int] = [2,3,4,5,6]
    var mission: Mission = .dance
    var target = 30
    var tone = "FirstLight"
    var enabled = true
    var route: [RitualStep] = []
    var scheduleMode: WakeSchedule = .weekly
    var datedAt = Date.now.addingTimeInterval(86400)
    var cycleStart = Calendar.current.startOfDay(for: .now)
    var workDays = 2, restDays = 2
    var skippedDates: [Date] = []
    var pausedUntil: Date?
    var nextOverride: Date?
    var snoozeMinutes = 0
    var wakeCheckMinutes = 0
    var gentleSound = false
    var isNap = false
    init() {}
    var steps: [RitualStep] { route.isEmpty ? [RitualStep(mission: mission,target: target)] : route }
    var routeText: String { steps.map(\.mission.title).joined(separator: " → ") }
    var isOneShot: Bool { scheduleMode == .dated || (scheduleMode == .weekly && weekdays.isEmpty) }
    var usesCalendarPlan: Bool { scheduleMode == .rotation || !skippedDates.isEmpty || pausedUntil != nil || nextOverride != nil || tone == "Surprise" }
    func removingExpiredExceptions(after date:Date = .now,calendar:Calendar = .current)->WakeAlarm {
        var copy=self;let today=calendar.startOfDay(for:date)
        copy.skippedDates.removeAll {$0 < today}
        if let pause=copy.pausedUntil,pause <= date {copy.pausedUntil=nil}
        if let override=copy.nextOverride,override < today {copy.nextOverride=nil}
        return copy
    }
    var timeText: String {
        let date = Calendar.current.date(from: DateComponents(year:2026,month:1,day:1,hour:hour,minute:minute)) ?? .now
        return date.formatted(date:.omitted,time:.shortened)
    }
    var repeatText: String {
        if isNap { return "Quick nap" }
        if scheduleMode == .dated { return datedAt.formatted(.dateTime.month(.abbreviated).day()) }
        if scheduleMode == .rotation { return "\(workDays) on · \(restDays) off" }
        if weekdays.isEmpty { return "Once" }
        if Set(weekdays) == Set(1...7) { return "Every day" }
        if Set(weekdays) == Set(2...6) { return "Weekdays" }
        return weekdays.filter { (1...7).contains($0) }.sorted().map { Calendar.current.shortWeekdaySymbols[$0-1] }.joined(separator:" · ")
    }
    func nextFire(after date: Date, calendar: Calendar = .current) -> Date? {
        if let override = nextOverride, override > date, pausedUntil.map({override >= $0}) ?? true { return override }
        if scheduleMode == .dated { return datedAt > date && (pausedUntil.map { datedAt >= $0 } ?? true) ? datedAt : nil }
        let lower = max(date, pausedUntil ?? date)
        var cursor = calendar.startOfDay(for: lower)
        for _ in 0..<740 {
            if let candidate = calendar.nextDate(after: cursor.addingTimeInterval(-1),matching:DateComponents(hour:hour,minute:minute,second:0),matchingPolicy:.nextTime,repeatedTimePolicy:.first), calendar.isDate(candidate,inSameDayAs:cursor), candidate > date, candidate >= lower {
                let skipped = skippedDates.contains { calendar.isDate($0,inSameDayAs:candidate) } || nextOverride.map {calendar.isDate($0,inSameDayAs:candidate)} == true
                let matches: Bool
                if scheduleMode == .rotation {
                    let offset = calendar.dateComponents([.day],from:calendar.startOfDay(for:cycleStart),to:cursor).day ?? 0
                    let cycle = max(1,workDays + restDays)
                    matches = offset >= 0 && offset % cycle < workDays
                } else { matches = weekdays.isEmpty || weekdays.contains(calendar.component(.weekday,from:candidate)) }
                if matches && !skipped { return candidate }
            }
            guard let tomorrow = calendar.date(byAdding:.day,value:1,to:cursor) else { break }; cursor = tomorrow
        }
        return nil
    }
    func occurrences(after date:Date = .now,count:Int = 14,calendar:Calendar = .current) -> [Date] {
        var result:[Date] = [], cursor = date
        for _ in 0..<count { guard let next = nextFire(after:cursor,calendar:calendar) else { break }; result.append(next); cursor = next; if isOneShot { break } }
        return result
    }
    func chosenTone(for date:Date,calendar:Calendar = .current) -> String {
        guard tone == "Surprise" else { return tone }
        let day = calendar.ordinality(of:.day,in:.era,for:date) ?? 0
        let seed = Int(id.uuid.0)
        return ["FirstLight","SoftStart","RiseAndShine","BrightMarimba","QuietKeys","MorningGroove"][(day + seed) % 6]
    }
    enum CodingKeys:String,CodingKey { case id,hour,minute,label,weekdays,mission,target,tone,enabled,route,scheduleMode,datedAt,cycleStart,workDays,restDays,skippedDates,pausedUntil,nextOverride,snoozeMinutes,wakeCheckMinutes,gentleSound,isNap }
    init(from decoder:any Decoder) throws {
        self.init(); let c=try decoder.container(keyedBy:CodingKeys.self)
        id=try c.decode(UUID.self,forKey:.id); hour=try c.decode(Int.self,forKey:.hour); minute=try c.decode(Int.self,forKey:.minute)
        label=try c.decode(String.self,forKey:.label); weekdays=try c.decode([Int].self,forKey:.weekdays)
        mission=try c.decode(Mission.self,forKey:.mission); target=try c.decode(Int.self,forKey:.target)
        tone=try c.decode(String.self,forKey:.tone); enabled=try c.decode(Bool.self,forKey:.enabled)
        route=try c.decodeIfPresent([RitualStep].self,forKey:.route) ?? []
        scheduleMode=try c.decodeIfPresent(WakeSchedule.self,forKey:.scheduleMode) ?? .weekly
        datedAt=try c.decodeIfPresent(Date.self,forKey:.datedAt) ?? datedAt
        cycleStart=try c.decodeIfPresent(Date.self,forKey:.cycleStart) ?? cycleStart
        workDays=try c.decodeIfPresent(Int.self,forKey:.workDays) ?? 2; restDays=try c.decodeIfPresent(Int.self,forKey:.restDays) ?? 2
        skippedDates=try c.decodeIfPresent([Date].self,forKey:.skippedDates) ?? []
        pausedUntil=try c.decodeIfPresent(Date.self,forKey:.pausedUntil); nextOverride=try c.decodeIfPresent(Date.self,forKey:.nextOverride)
        snoozeMinutes=try c.decodeIfPresent(Int.self,forKey:.snoozeMinutes) ?? 0; wakeCheckMinutes=try c.decodeIfPresent(Int.self,forKey:.wakeCheckMinutes) ?? 0
        gentleSound=try c.decodeIfPresent(Bool.self,forKey:.gentleSound) ?? false; isNap=try c.decodeIfPresent(Bool.self,forKey:.isNap) ?? false
    }
}
struct CompletedStep:Codable,Equatable { var mission:Mission; var amount:Int; var mode:String }
struct Sunrise: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var alarmID: UUID
    var mission: Mission
    var amount: Int
    var mood: String?
    var steps:[CompletedStep]?
    var durationSeconds:Double?
    var wakeCheckConfirmedAt:Date?
}
struct PendingWakeCheck:Codable,Identifiable {
    var id:UUID
    var alarmID:UUID
    var sunriseID:UUID
    var date:Date
}
enum Journal {
    static func streak(_ records:[Sunrise],now:Date = .now,calendar:Calendar = .current)->Int {
        let days=Set(records.map {calendar.startOfDay(for:$0.date)})
        var cursor=calendar.startOfDay(for:now)
        if !days.contains(cursor) { cursor=calendar.date(byAdding:.day,value:-1,to:cursor)! }
        var count=0
        while days.contains(cursor) { count += 1; guard let previous=calendar.date(byAdding:.day,value:-1,to:cursor) else {break}; cursor=previous }
        return count
    }
}
struct RepCounter {
    private(set) var count=0
    private var armed=false, lowered=false
    private var lastCount = -Double.infinity
    mutating func consume(angle:Double?,time:TimeInterval)->Bool {
        guard let angle,angle.isFinite else {armed=false;lowered=false;return false}
        if angle > 150 {
            if armed && lowered && time-lastCount >= 0.9 {count += 1;lowered=false;lastCount=time;return true}
            armed=true
        } else if angle < 100 && armed {lowered=true}
        return false
    }
}

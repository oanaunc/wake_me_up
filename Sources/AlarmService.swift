import SwiftUI
import AlarmKit
import AppIntents
import ActivityKit


public struct BeginMorningIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Begin your morning"
    public static var openAppWhenRun = true
    @Parameter(title: "Alarm identifier") public var alarmID: String
    public init() { alarmID = "" }
    public init(id: UUID) { alarmID = id.uuidString }
    @MainActor public func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(alarmID, forKey: "pendingMorning")
        if let id=UUID(uuidString:alarmID) {
            if let store=WakeStore.liveStore {await store.refillAfterDismissing(id)}
            else {
                // Re-arm from persisted configuration without overwriting a foreground store.
                let url=URL.applicationSupportDirectory.appending(path:"wake-me-up.json")
                if let data=try? Data(contentsOf:url),let saved=try? JSONDecoder().decode(SavedWake.self,from:data),
                   let alarm=saved.alarms.first(where:{$0.id == id}),alarm.enabled,alarm.usesCalendarPlan,!alarm.isOneShot {
                    try? AlarmService.stop(id)
                    try? AlarmService.cancel(id)
                    try? await AlarmService.schedule(alarm)
                }
            }
        }
        NotificationCenter.default.post(name: .init("wake.beginMorning"), object: nil)
        return .result()
    }
}

@MainActor
enum AlarmService {
    static var authorized: Bool { AlarmManager.shared.authorizationState == .authorized }
    static func enable() async throws {
        guard try await AlarmManager.shared.requestAuthorization() == .authorized else {
            throw WakeError.message("Alarm access is off. Enable Wake Me Up in Settings → Apps → Wake Me Up → Alarms before saving an active alarm.")
        }
    }
    static func schedule(_ alarm: WakeAlarm) async throws {
        let days: [Locale.Weekday] = [.sunday,.monday,.tuesday,.wednesday,.thursday,.friday,.saturday]
        var schedules: [Alarm.Schedule]
        if alarm.scheduleMode == .dated || alarm.usesCalendarPlan {
            schedules = AlarmPlan.dates(alarm).map { .fixed($0) }
        } else {
            let recurrence: Alarm.Schedule.Relative.Recurrence = alarm.weekdays.isEmpty ? .never : .weekly(alarm.weekdays.map { days[$0-1] })
            schedules = [.relative(.init(time:.init(hour:alarm.hour,minute:alarm.minute),repeats:recurrence))]
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-alarm-integration") { schedules = [.fixed(Date.now.addingTimeInterval(15))] }
        #endif
        guard !schedules.isEmpty else { throw WakeError.message("Choose a future alarm date.") }
        do {
            for (index,schedule) in schedules.enumerated() {
                let snooze = alarm.snoozeMinutes > 0
                let first = alarm.steps.first?.mission ?? alarm.mission
                let button = AlarmButton(text:snooze ? "Snooze" : "Start moving",textColor:.white,systemImageName:snooze ? "zzz" : first.symbol)
                let alert = AlarmPresentation.Alert(title:LocalizedStringResource(stringLiteral:"\(alarm.label) · \(first.title)"),secondaryButton:button,secondaryButtonBehavior:snooze ? .countdown : .custom)
                let countdown = snooze ? AlarmPresentation.Countdown(title:"A few more minutes") : nil
                let attributes = AlarmAttributes(presentation:AlarmPresentation(alert:alert,countdown:countdown),metadata:WakeMetadata(alarmID:alarm.id.uuidString),tintColor:Color.orange)
                let date:Date
                if case .fixed(let fixed) = schedule { date = fixed } else { date = alarm.nextFire(after:.now) ?? .now }
                let tone = alarm.chosenTone(for:date)
                let filename = ToneLibrary.alarmFilename(tone,gentle:alarm.gentleSound)
                var sound:AlertConfiguration.AlertSound = filename.map { .named($0) } ?? .default
                #if DEBUG && targetEnvironment(simulator)
                if ProcessInfo.processInfo.arguments.contains("-alarm-integration") { sound = .default }
                #endif
                let configuration = AlarmManager.AlarmConfiguration(countdownDuration:snooze ? .init(preAlert:nil,postAlert:TimeInterval(alarm.snoozeMinutes*60)) : nil,schedule:schedule,attributes:attributes,stopIntent:BeginMorningIntent(id:alarm.id),secondaryIntent:snooze ? nil : BeginMorningIntent(id:alarm.id),sound:sound)
                _ = try await AlarmManager.shared.schedule(id:AlarmPlan.instanceID(alarm.id,index),configuration:configuration)
            }
        } catch {
            try? cancel(alarm.id)
            throw error
        }
    }
    static func cancel(_ id: UUID) throws {
        let existing = try AlarmManager.shared.alarms
        for index in 0..<AlarmPlan.count {
            let instance = AlarmPlan.instanceID(id,index)
            if existing.contains(where:{$0.id == instance}) { try AlarmManager.shared.cancel(id:instance) }
        }
    }
    static func stop(_ id: UUID) throws {
        let existing = try AlarmManager.shared.alarms
        for index in 0..<AlarmPlan.count {
            let instance = AlarmPlan.instanceID(id,index)
            if existing.contains(where:{$0.id == instance && $0.state == .alerting}) {try AlarmManager.shared.stop(id:instance)}
        }
    }

}

enum WakeError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): text } }
}

@MainActor protocol AlarmScheduling {
    var authorized: Bool { get }
    func enable() async throws
    func schedule(_ alarm: WakeAlarm) async throws
    func cancel(_ id: UUID) throws
    func stop(_ id: UUID) throws
}
@MainActor struct SystemAlarms: AlarmScheduling {
    var authorized: Bool { AlarmService.authorized }
    func enable() async throws { try await AlarmService.enable() }
    func schedule(_ alarm: WakeAlarm) async throws { try await AlarmService.schedule(alarm) }
    func cancel(_ id: UUID) throws { try AlarmService.cancel(id) }
    func stop(_ id: UUID) throws { try AlarmService.stop(id) }
}

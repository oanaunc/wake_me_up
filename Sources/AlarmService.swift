import SwiftUI
import AlarmKit
import AppIntents
import ActivityKit

struct WakeMetadata: AlarmMetadata { var alarmID: String }

public struct BeginMorningIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Begin your morning"
    public static var openAppWhenRun = true
    @Parameter(title: "Alarm identifier") public var alarmID: String
    public init() { alarmID = "" }
    public init(id: UUID) { alarmID = id.uuidString }
    @MainActor public func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(alarmID, forKey: "pendingMorning")
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
        let weekdays: [Locale.Weekday] = [.sunday,.monday,.tuesday,.wednesday,.thursday,.friday,.saturday]
        let recurrence: Alarm.Schedule.Relative.Recurrence = alarm.weekdays.isEmpty ? .never : .weekly(alarm.weekdays.map { weekdays[$0 - 1] })
        var schedule = Alarm.Schedule.relative(.init(time: .init(hour: alarm.hour, minute: alarm.minute), repeats: recurrence))
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-alarm-integration") {
            schedule = .fixed(Date.now.addingTimeInterval(15))
        }
        #endif
        let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: "\(alarm.label) · \(alarm.mission.title)"), secondaryButton: AlarmButton(text: "Start moving", textColor: .white, systemImageName: alarm.mission.symbol), secondaryButtonBehavior: .custom)
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: WakeMetadata(alarmID: alarm.id.uuidString), tintColor: Color.orange)
        var sound: AlertConfiguration.AlertSound = Bundle.main.url(forResource: alarm.tone + "Alarm", withExtension: "caf") == nil ? .default : .named(alarm.tone + "Alarm.caf")
        #if DEBUG && targetEnvironment(simulator)
        // iOS 26.5 simulator's ToneLibrary crashes SpringBoard on custom alarm audio.
        // Integration verifies delivery with its system sound; hardware verifies bundled tones.
        if ProcessInfo.processInfo.arguments.contains("-alarm-integration") { sound = .default }
        #endif
        _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: .alarm(schedule: schedule, attributes: attributes, stopIntent: BeginMorningIntent(id: alarm.id), secondaryIntent: BeginMorningIntent(id: alarm.id), sound: sound))
    }
    static func cancel(_ id: UUID) throws {
        if try AlarmManager.shared.alarms.contains(where: { $0.id == id }) { try AlarmManager.shared.cancel(id: id) }
    }
    static func stop(_ id: UUID) throws {
        if try AlarmManager.shared.alarms.contains(where: { $0.id == id && $0.state == .alerting }) { try AlarmManager.shared.stop(id: id) }
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

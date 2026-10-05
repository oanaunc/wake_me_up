import SwiftUI
import AlarmKit
import UIKit

struct SavedWake: Codable {
    var alarms: [WakeAlarm] = []
    var sunrises: [Sunrise] = []
    var soundEnabled = true
    var pendingAlarmID: UUID?
}
struct MorningSession: Identifiable {
    let id = UUID()
    var alarm: WakeAlarm
    var practice: Bool
}

@MainActor @Observable
final class WakeStore {
    private(set) var saved = SavedWake()
    var session: MorningSession?
    var error: String?
    var busy = false
    var alarmAccess = AlarmService.authorized
    private var monitor: Task<Void, Never>?
    private var intentMonitor: Task<Void, Never>?
    private var authMonitor: Task<Void, Never>?
    private let url: URL
    private let alarmClient: any AlarmScheduling
    var alarms: [WakeAlarm] { saved.alarms }
    var sunrises: [Sunrise] { saved.sunrises }
    var streak: Int { Journal.streak(sunrises) }
    var soundEnabled: Bool { saved.soundEnabled }
    init(storageURL: URL? = nil, alarmClient: (any AlarmScheduling)? = nil, observe: Bool = true) {
        url = storageURL ?? URL.applicationSupportDirectory.appending(path: "wake-me-up.json")
        self.alarmClient = alarmClient ?? SystemAlarms()
        alarmAccess = self.alarmClient.authorized
        if FileManager.default.fileExists(atPath: url.path) {
            do { saved = try JSONDecoder().decode(SavedWake.self, from: Data(contentsOf: url)) }
            catch { self.error = "Your saved mornings could not be read. The file has been kept. \(error.localizedDescription)" }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-alarm-integration") {
            for alarm in saved.alarms { try? self.alarmClient.cancel(alarm.id) }
            saved = SavedWake()
            try? FileManager.default.removeItem(at: url)
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-demo") {
            var demo = WakeAlarm(); demo.enabled = false
            saved.alarms = [demo]
        }
        #endif
        guard observe else { return }
        monitor = Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                guard let self else { return }
                self.alarmAccess = AlarmService.authorized
                if let ringing = alarms.first(where: { $0.state == .alerting }), let alarm = self.alarms.first(where: { $0.id == ringing.id }), self.session == nil {
                    // Keep recovery state even when iOS dismisses the alert before foregrounding.
                    // Recording a pending ritual never stops a background system alarm.
                    if self.saved.pendingAlarmID != alarm.id {
                        var value = self.saved; value.pendingAlarmID = alarm.id
                        do { try self.commit(value) } catch { self.error = "Ritual recovery could not be saved: \(error.localizedDescription)" }
                    }
                    if UIApplication.shared.applicationState == .active { self.begin(alarm, practice: false) }
                }
            }
        }
        intentMonitor = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .init("wake.beginMorning")) {
                if UIApplication.shared.applicationState == .active { self?.resumePending() }
            }
        }
        authMonitor = Task { [weak self] in
            for await state in AlarmManager.shared.authorizationUpdates { self?.alarmAccess = state == .authorized }
        }
    }
    private func commit(_ value: SavedWake) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        saved = value
    }
    func saveAlarm(_ alarm: WakeAlarm, plus: Bool) async -> Bool {
        guard !busy else { return false }
        let old = alarms.first(where: { $0.id == alarm.id })
        if old == nil && alarms.count >= (plus ? 20 : 2) { error = plus ? "You can save up to 20 alarms." : "Your two free alarms are ready. Edit one, or unlock more with Plus."; return false }
        busy = true; defer { busy = false }
        do {
            if alarm.enabled { try await alarmClient.enable(); alarmAccess = true }
            try alarmClient.cancel(alarm.id)
            do {
                if alarm.enabled { try await alarmClient.schedule(alarm) }
                var updated = saved
                if let index = updated.alarms.firstIndex(where: { $0.id == alarm.id }) { updated.alarms[index] = alarm }
                else { updated.alarms.append(alarm) }
                try commit(updated)
                return true
            } catch {
                try? alarmClient.cancel(alarm.id)
                if let old, old.enabled {
                    do { try await alarmClient.schedule(old) }
                    catch { self.error = "The alarm could not be restored. Please re-enable it before relying on it. \(error.localizedDescription)"; return false }
                }
                throw error
            }
        } catch { self.error = "Alarm not saved: \(error.localizedDescription)"; return false }
    }
    func delete(_ alarm: WakeAlarm) async -> Bool {
        guard !busy else { return false }
        busy = true; defer { busy = false }
        do {
            try alarmClient.cancel(alarm.id)
            var updated = saved; updated.alarms.removeAll { $0.id == alarm.id }
            do { try commit(updated) }
            catch { if alarm.enabled { try? await alarmClient.schedule(alarm) }; throw error }
            return true
        } catch { self.error = "Alarm not removed: \(error.localizedDescription)"; return false }
    }
    func begin(_ alarm: WakeAlarm, practice: Bool) {
        guard session == nil else { return }
        if !practice { do { try alarmClient.stop(alarm.id) } catch { self.error = "Use the system Stop control if the alarm is still sounding." } }
        session = MorningSession(alarm: alarm, practice: practice)
        if !practice { var value = saved; value.pendingAlarmID = alarm.id; do { try commit(value) } catch { self.error = "Ritual recovery could not be saved: \(error.localizedDescription)" } }
    }
    func resumePending() {
        alarmAccess = alarmClient.authorized
        if let text = UserDefaults.standard.string(forKey: "pendingMorning"), let id = UUID(uuidString: text), let alarm = alarms.first(where: { $0.id == id }) {
            UserDefaults.standard.removeObject(forKey: "pendingMorning")
            begin(alarm, practice: false)
        }
        if let ringing = try? AlarmManager.shared.alarms.first(where: { $0.state == .alerting }), let alarm = alarms.first(where: { $0.id == ringing.id }) { begin(alarm, practice: false) }
        if session == nil, let id = saved.pendingAlarmID, let alarm = alarms.first(where: { $0.id == id }) { begin(alarm, practice: false) }
    }
    func complete(_ session: MorningSession, mood: String?) -> Bool {
        guard !session.practice else { return true }
        do {
            var updated = saved
            updated.pendingAlarmID = nil
            // Re-opening the same alarm cannot add duplicate credit for a morning.
            if !updated.sunrises.contains(where: { $0.alarmID == session.alarm.id && Calendar.current.isDateInToday($0.date) }) {
                updated.sunrises.append(Sunrise(alarmID: session.alarm.id, mission: session.alarm.mission, amount: session.alarm.target, mood: mood))
            }
            if session.alarm.weekdays.isEmpty, let index = updated.alarms.firstIndex(where: { $0.id == session.alarm.id }) { updated.alarms[index].enabled = false }
            try commit(updated); return true
        } catch { self.error = "Morning not saved: \(error.localizedDescription)"; return false }
    }
    func setSound(_ enabled: Bool) { var value = saved; value.soundEnabled = enabled; do { try commit(value) } catch { self.error = error.localizedDescription } }
    func abandon() { var value = saved; value.pendingAlarmID = nil; do { try commit(value) } catch { self.error = error.localizedDescription } }
    func clearJournal() { var value = saved; value.sunrises = []; do { try commit(value) } catch { self.error = error.localizedDescription } }
}

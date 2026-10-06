import SwiftUI
import AlarmKit
import UIKit

struct SavedWake: Codable {
    var alarms:[WakeAlarm] = []
    var sunrises:[Sunrise] = []
    var soundEnabled=true
    var pendingAlarmID:UUID?
    var pendingSession:MorningSession?
    var destinations:[Destination] = []
    var importedTones:[ImportedTone] = []
    var wakeChecks:[PendingWakeCheck] = []
    var plannedThrough:[String:Date] = [:]
    var ritualVolume=0.55
    var hideStreak=false
    var bedtimeEnabled=false
    var bedtimeHour=22, bedtimeMinute=0
    var sleepGoalHours=8.0
    var presets:[RoutePreset] = []
    init() {}
    enum CodingKeys:String,CodingKey {case alarms,sunrises,soundEnabled,pendingAlarmID,pendingSession,destinations,importedTones,wakeChecks,plannedThrough,ritualVolume,hideStreak,bedtimeEnabled,bedtimeHour,bedtimeMinute,sleepGoalHours,presets}
    init(from decoder:any Decoder) throws {
        self.init();let c=try decoder.container(keyedBy:CodingKeys.self)
        alarms=try c.decodeIfPresent([WakeAlarm].self,forKey:.alarms) ?? []
        sunrises=try c.decodeIfPresent([Sunrise].self,forKey:.sunrises) ?? []
        soundEnabled=try c.decodeIfPresent(Bool.self,forKey:.soundEnabled) ?? true
        pendingAlarmID=try c.decodeIfPresent(UUID.self,forKey:.pendingAlarmID)
        pendingSession=try c.decodeIfPresent(MorningSession.self,forKey:.pendingSession)
        destinations=try c.decodeIfPresent([Destination].self,forKey:.destinations) ?? []
        importedTones=try c.decodeIfPresent([ImportedTone].self,forKey:.importedTones) ?? []
        wakeChecks=try c.decodeIfPresent([PendingWakeCheck].self,forKey:.wakeChecks) ?? []
        plannedThrough=try c.decodeIfPresent([String:Date].self,forKey:.plannedThrough) ?? [:]
        ritualVolume=try c.decodeIfPresent(Double.self,forKey:.ritualVolume) ?? 0.55
        hideStreak=try c.decodeIfPresent(Bool.self,forKey:.hideStreak) ?? false
        bedtimeEnabled=try c.decodeIfPresent(Bool.self,forKey:.bedtimeEnabled) ?? false
        bedtimeHour=try c.decodeIfPresent(Int.self,forKey:.bedtimeHour) ?? 22
        bedtimeMinute=try c.decodeIfPresent(Int.self,forKey:.bedtimeMinute) ?? 0
        sleepGoalHours=try c.decodeIfPresent(Double.self,forKey:.sleepGoalHours) ?? 8
        presets=try c.decodeIfPresent([RoutePreset].self,forKey:.presets) ?? []
    }
}
struct MorningSession:Identifiable,Codable {
    var id=UUID()
    var alarm:WakeAlarm
    var practice:Bool
    var steps:[RitualStep]
    var stepIndex=0
    var completedSteps:[CompletedStep] = []
    var startedAt=Date()
    init(alarm:WakeAlarm,practice:Bool) {self.alarm=alarm;self.practice=practice;steps=alarm.steps}
    var currentStep:RitualStep {steps[min(stepIndex,steps.count-1)]}
    var isLastStep:Bool {stepIndex == steps.count-1}
}
struct RoutePreset:Codable,Identifiable {
    var id=UUID()
    var name:String
    var steps:[RitualStep]
}

@MainActor @Observable
final class WakeStore {
    static weak var liveStore:WakeStore?
    private(set) var saved = SavedWake()
    var session: MorningSession?
    var awakeCheck: PendingWakeCheck?
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
    var destinations:[Destination] {saved.destinations}
    var importedTones:[ImportedTone] {saved.importedTones}
    var ritualVolume:Double {saved.ritualVolume}
    var hideStreak:Bool {saved.hideStreak}
    var pendingChecks:[PendingWakeCheck] {saved.wakeChecks.filter {$0.date > .now.addingTimeInterval(-86400)}}
    var presets:[RoutePreset] {saved.presets}
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
        WakeStore.liveStore=self
        monitor = Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                guard let self else { return }
                self.alarmAccess = AlarmService.authorized
                if let ringing = alarms.first(where: { $0.state == .alerting }), let alarm = AlarmPlan.owner(of:ringing.id,alarms:self.alarms), self.session == nil {
                    // Snoozing a background alert must not create a pending route.
                    // The explicit Stop / Start moving intent carries recovery into the app.
                    if UIApplication.shared.applicationState == .active { self.begin(alarm, practice: false) }
                }
                if UIApplication.shared.applicationState == .active,
                   let ringing=alarms.first(where:{$0.state == .alerting}),
                   let check=self.saved.wakeChecks.first(where:{$0.id == ringing.id}) {
                    try? self.alarmClient.stop(check.id); self.awakeCheck=check
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
        if old == nil && alarms.filter { !$0.isNap }.count >= (plus ? 20 : 2) && !alarm.isNap { error = plus ? "You can save up to 20 alarms." : "Your two free alarms are ready. Edit one, or unlock more with Plus."; return false }
        guard (0...23).contains(alarm.hour), (0...59).contains(alarm.minute),
              alarm.weekdays.allSatisfy({(1...7).contains($0)}),
              (1...30).contains(alarm.workDays), (1...30).contains(alarm.restDays),
              alarm.steps.count <= 5,
              alarm.steps.allSatisfy({$0.mission.targetRange.contains($0.target) && ($0.mission != .words || !FocusChallenge.normalized($0.intention).isEmpty)}) else {
            error="Choose valid alarm times, comfortable targets, and a non-empty intention."; return false
        }
        busy = true; defer { busy = false }
        do {
            if alarm.enabled { try await alarmClient.enable(); alarmAccess = true }
            try alarmClient.cancel(alarm.id)
            do {
                if alarm.enabled { try await alarmClient.schedule(alarm) }
                var updated = saved
                if let index = updated.alarms.firstIndex(where: { $0.id == alarm.id }) { updated.alarms[index] = alarm }
                else { updated.alarms.append(alarm) }
                if alarm.enabled && alarm.usesCalendarPlan {updated.plannedThrough[alarm.id.uuidString]=AlarmPlan.dates(alarm).last}
                else {updated.plannedThrough[alarm.id.uuidString]=nil}
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
        let checks=saved.wakeChecks.filter {$0.alarmID == alarm.id}
        do {
            try alarmClient.cancel(alarm.id)
            var updated = saved; updated.alarms.removeAll { $0.id == alarm.id }; updated.plannedThrough[alarm.id.uuidString]=nil
            for check in updated.wakeChecks.filter({$0.alarmID == alarm.id}) {try alarmClient.cancel(check.id)}
            updated.wakeChecks.removeAll {$0.alarmID == alarm.id}
            try commit(updated)
            return true
        } catch {
            let failure=error
            do {
                if alarm.enabled {try await alarmClient.schedule(alarm)}
                for check in checks where check.date > .now {try await alarmClient.schedule(checkAlarm(check,parent:alarm))}
                self.error="Alarm not removed: \(failure.localizedDescription)"
            } catch {self.error="The alarm could not be removed or fully restored. Re-enable it before relying on it. \(error.localizedDescription)"}
            return false
        }
    }
    private func checkAlarm(_ check:PendingWakeCheck,parent:WakeAlarm)->WakeAlarm {
        var alarm=WakeAlarm();alarm.id=check.id;alarm.label="Still awake?";alarm.scheduleMode = .dated
        alarm.datedAt=check.date;alarm.weekdays=[];alarm.mission = .sunTaps;alarm.target=3
        alarm.tone=parent.tone == "Surprise" ? "FirstLight" : parent.tone
        return alarm
    }
    func begin(_ alarm: WakeAlarm, practice: Bool) {
        guard session == nil else { return }
        if !practice { do { try alarmClient.stop(alarm.id) } catch { self.error = "Use the system Stop control if the alarm is still sounding." } }
        if !practice, let pending=saved.pendingSession, pending.alarm.id == alarm.id {session=pending}
        else {session=MorningSession(alarm:alarm,practice:practice)}
        if !practice { var value = saved; value.pendingAlarmID = alarm.id; value.pendingSession=session; do { try commit(value) } catch { self.error = "Ritual recovery could not be saved: \(error.localizedDescription)" } }
    }
    func resumePending() {
        if let route=UserDefaults.standard.string(forKey:"pendingPractice") {
            UserDefaults.standard.removeObject(forKey:"pendingPractice")
            if session == nil {
                var alarm=WakeAlarm()
                alarm.route = route == "focus" ? [RitualStep(mission:.math),RitualStep(mission:.march),RitualStep(mission:.daylight)] : route == "joy" ? [RitualStep(mission:.sunTaps),RitualStep(mission:.dance),RitualStep(mission:.water)] : [RitualStep(mission:.breathe),RitualStep(mission:.stretch),RitualStep(mission:.daylight)]
                begin(alarm,practice:true)
            }
        }
        let nap=UserDefaults.standard.integer(forKey:"pendingNapMinutes")
        if nap > 0 {UserDefaults.standard.removeObject(forKey:"pendingNapMinutes");Task {await quickNap(minutes:min(180,max(1,nap)),plus:false)}}
        alarmAccess = alarmClient.authorized
        if let text = UserDefaults.standard.string(forKey: "pendingMorning"), let id = UUID(uuidString: text), let alarm = alarms.first(where: { $0.id == id }) {
            UserDefaults.standard.removeObject(forKey: "pendingMorning")
            begin(alarm, practice: false)
        }
        if let text=UserDefaults.standard.string(forKey:"pendingMorning"),let id=UUID(uuidString:text),let check=saved.wakeChecks.first(where:{$0.id == id}) {
            UserDefaults.standard.removeObject(forKey:"pendingMorning");try? alarmClient.stop(id);awakeCheck=check
        }
        if let ringing = try? AlarmManager.shared.alarms.first(where: { $0.state == .alerting }), let alarm = AlarmPlan.owner(of:ringing.id,alarms:alarms) { begin(alarm, practice: false) }
        if session == nil, let id = saved.pendingAlarmID, let alarm = alarms.first(where: { $0.id == id }) { begin(alarm, practice: false) }
    }
    func complete(_ session: MorningSession, mood: String?) -> Bool {
        guard !session.practice else { return true }
        do {
            var updated = saved
            updated.pendingAlarmID = nil; updated.pendingSession=nil
            // Re-opening the same alarm cannot add duplicate credit for a morning.
            if !updated.sunrises.contains(where: { $0.alarmID == session.alarm.id && Calendar.current.isDateInToday($0.date) }) {
                var record=Sunrise(alarmID:session.alarm.id,mission:session.alarm.mission,amount:session.alarm.target,mood:mood)
                record.steps=session.completedSteps
                record.durationSeconds=max(0,Date.now.timeIntervalSince(session.startedAt))
                updated.sunrises.append(record)
            }
            if session.alarm.isOneShot, let index = updated.alarms.firstIndex(where: { $0.id == session.alarm.id }) { updated.alarms[index].enabled = false }
            try commit(updated); return true
        } catch { self.error = "Morning not saved: \(error.localizedDescription)"; return false }
    }
    func setSound(_ enabled: Bool) { var value = saved; value.soundEnabled = enabled; do { try commit(value) } catch { self.error = error.localizedDescription } }
    func abandon() { var value = saved; value.pendingAlarmID = nil; value.pendingSession=nil; do { try commit(value) } catch { self.error = error.localizedDescription } }
    func clearJournal() {
        var value=saved;value.sunrises=[]
        do {for check in value.wakeChecks {try alarmClient.cancel(check.id)};value.wakeChecks=[];try commit(value)}
        catch {self.error=error.localizedDescription}
    }
    func advance(_ current:MorningSession,mode:String) {
        guard !current.isLastStep else {return}
        var next=current; next.completedSteps.append(CompletedStep(mission:current.currentStep.mission,amount:current.currentStep.target,mode:mode))
        next.stepIndex += 1
        var updated=saved
        if !current.practice {updated.pendingSession=next}
        do {try commit(updated);session=next} catch {self.error="Your next step could not be saved."}
    }
    func finish(_ current:MorningSession,mood:String?,mode:String) async -> Bool {
        var finished=current
        finished.completedSteps.append(CompletedStep(mission:current.currentStep.mission,amount:current.currentStep.target,mode:mode))
        guard complete(finished,mood:mood) else {return false}
        if !current.practice && current.alarm.wakeCheckMinutes > 0,
           let sunrise=saved.sunrises.last(where:{$0.alarmID == current.alarm.id}) {
            for check in saved.wakeChecks.filter({$0.alarmID == current.alarm.id}) {try? alarmClient.cancel(check.id)}
            var followup=WakeAlarm();followup.id=UUID();followup.label="Still awake?";followup.scheduleMode = .dated
            followup.datedAt=Date.now.addingTimeInterval(Double(current.alarm.wakeCheckMinutes*60));followup.weekdays=[]
            followup.tone=current.alarm.tone == "Surprise" ? "FirstLight" : current.alarm.tone
            followup.mission = .sunTaps;followup.target=3
            let check=PendingWakeCheck(id:followup.id,alarmID:current.alarm.id,sunriseID:sunrise.id,date:followup.datedAt)
            do {
                try await alarmClient.schedule(followup)
                var updated=saved;updated.wakeChecks.removeAll {$0.alarmID == current.alarm.id};updated.wakeChecks.append(check)
                do {try commit(updated)} catch {try? alarmClient.cancel(check.id);throw error}
            } catch {self.error="Your sunrise is saved, but the wake-up check could not be scheduled. \(error.localizedDescription)"}
        }
        await refreshSchedules()
        return true
    }
    func confirmAwake(_ check:PendingWakeCheck)->Bool {
        var updated=saved
        if let index=updated.sunrises.firstIndex(where:{$0.id == check.sunriseID}) {updated.sunrises[index].wakeCheckConfirmedAt = .now}
        updated.wakeChecks.removeAll {$0.id == check.id}
        do {try alarmClient.cancel(check.id);try commit(updated);awakeCheck=nil;return true}
        catch {self.error="Your check-in could not be saved.";return false}
    }
    func cancelCheck(_ check:PendingWakeCheck) {
        var updated=saved;updated.wakeChecks.removeAll {$0.id == check.id}
        do {try alarmClient.cancel(check.id);try commit(updated);awakeCheck=nil}
        catch {self.error="The wake-up check could not be canceled."}
    }
    func skipNext(_ alarm:WakeAlarm,plus:Bool) async {
        guard let date=alarm.nextFire(after:.now) else {return}
        var copy=alarm
        if copy.isOneShot {copy.enabled=false} else {copy.skippedDates.append(date);copy.nextOverride=nil}
        _=await saveAlarm(copy,plus:plus)
    }
    func quickNap(minutes:Int,plus:Bool) async {
        if let prior=alarms.first(where:\.isNap), !(await delete(prior)) {return}
        var alarm=WakeAlarm();alarm.label="A little rest";alarm.isNap=true;alarm.scheduleMode = .dated;alarm.weekdays=[]
        alarm.datedAt=Date.now.addingTimeInterval(Double(minutes*60));alarm.hour=Calendar.current.component(.hour,from:alarm.datedAt);alarm.minute=Calendar.current.component(.minute,from:alarm.datedAt)
        alarm.mission = .stretch;alarm.target=30;alarm.tone="SoftStart"
        _=await saveAlarm(alarm,plus:plus)
    }
    func refillAfterDismissing(_ id:UUID) async {
        guard let alarm=alarms.first(where:{$0.id == id}),alarm.enabled,alarm.usesCalendarPlan,!alarm.isOneShot else {return}
        try? alarmClient.stop(id)
        _=await saveAlarm(alarm.removingExpiredExceptions(),plus:true)
    }
    func refreshSchedules() async {
        guard !busy else {return}
        for alarm in alarms where alarm.enabled && alarm.usesCalendarPlan && !alarm.isOneShot && session?.alarm.id != alarm.id {
            let revised=alarm.removingExpiredExceptions()
            let last=revised.usesCalendarPlan ? AlarmPlan.dates(revised).last : nil
            if saved.plannedThrough[alarm.id.uuidString] != last || revised.skippedDates != alarm.skippedDates || revised.pausedUntil != alarm.pausedUntil || revised.nextOverride != alarm.nextOverride {
                // A playing/snoozed system alarm must survive a foreground refresh.
                if let active=try? AlarmManager.shared.alarms,
                   active.contains(where:{$0.state != .scheduled && AlarmPlan.owner(of:$0.id,alarms:[alarm]) != nil}) {continue}
                _=await saveAlarm(revised,plus:true)
            }
        }
    }
    func pauseAll(until date:Date,plus:Bool) async -> Bool {
        guard !busy else {return false}
        busy=true;defer {busy=false}
        let old=saved; var updated=saved
        do {
            for index in updated.alarms.indices where updated.alarms[index].enabled {
                updated.alarms[index].pausedUntil=date
                try alarmClient.cancel(updated.alarms[index].id)
                try await alarmClient.schedule(updated.alarms[index])
                updated.plannedThrough[updated.alarms[index].id.uuidString]=AlarmPlan.dates(updated.alarms[index]).last
            }
            try commit(updated);return true
        } catch {
            let failure=error;var restored=true
            for alarm in old.alarms where alarm.enabled {
                do {try alarmClient.cancel(alarm.id);try await alarmClient.schedule(alarm)} catch {restored=false}
            }
            self.error=restored ? "The pause could not be saved; prior alarms were restored. \(failure.localizedDescription)" : "The pause failed and some alarms could not be restored. Re-enable your alarms before relying on them."
            return false
        }
    }
    func addDestination(name:String,code:String) {
        guard !code.isEmpty else {return}
        var updated=saved;updated.destinations.append(Destination(name:String(name.prefix(48)),digest:Destination.hash(code)))
        do {try commit(updated)} catch {self.error="The destination could not be saved."}
    }
    func removeDestinations(_ ids:Set<UUID>) {
        var updated=saved;updated.destinations.removeAll {ids.contains($0.id)}
        for index in updated.alarms.indices {
            for step in updated.alarms[index].route.indices where updated.alarms[index].route[step].destinationID.map({ids.contains($0)}) == true {updated.alarms[index].route[step].destinationID=nil}
        }
        for index in updated.presets.indices {
            for step in updated.presets[index].steps.indices where updated.presets[index].steps[step].destinationID.map({ids.contains($0)}) == true {updated.presets[index].steps[step].destinationID=nil}
        }
        do {try commit(updated)} catch {self.error="The destinations could not be removed."}
    }
    func removePresets(_ ids:Set<UUID>) {
        var updated=saved;updated.presets.removeAll {ids.contains($0.id)}
        do {try commit(updated)} catch {self.error="The routes could not be removed."}
    }
    func removeTone(_ tone:ImportedTone) {
        guard !alarms.contains(where:{$0.tone == tone.id}),saved.pendingSession?.alarm.tone != tone.id else {
            error="Change alarms using this sound before removing it.";return
        }
        var updated=saved;updated.importedTones.removeAll {$0.id == tone.id}
        do {try commit(updated);try FileManager.default.removeItem(at:ToneLibrary.directory.appending(path:tone.id+"Alarm.caf"))}
        catch {self.error="The sound could not be fully removed: \(error.localizedDescription)"}
    }
    func addTone(_ tone:ImportedTone) {var updated=saved;updated.importedTones.append(tone);do {try commit(updated)} catch {self.error="The sound could not be saved."}}
    func savePreset(name:String,steps:[RitualStep]) {var updated=saved;updated.presets.append(RoutePreset(name:String(name.prefix(48)),steps:steps));do {try commit(updated)} catch {self.error="The route could not be saved."}}
    func setPreferences(volume:Double? = nil,hideStreak:Bool? = nil,sleepHours:Double? = nil) {
        var updated=saved
        if let volume {updated.ritualVolume=min(1,max(0.05,volume))}
        if let hideStreak {updated.hideStreak=hideStreak}
        if let sleepHours {updated.sleepGoalHours=min(12,max(4,sleepHours))}
        do {try commit(updated)} catch {self.error=error.localizedDescription}
    }
    func setBedtime(enabled:Bool,hour:Int,minute:Int) async -> Bool {
        do {
            try await MorningNotifications.bedtime(enabled:enabled,hour:hour,minute:minute)
            var updated=saved;updated.bedtimeEnabled=enabled;updated.bedtimeHour=hour;updated.bedtimeMinute=minute
            try commit(updated);return true
        } catch {self.error=error.localizedDescription;return false}
    }
    func exportJournal()->URL? {
        let quote:(String)->String = {"\"" + $0.replacingOccurrences(of:"\"",with:"\"\"") + "\""}
        var lines=["date,alarm_id,mood,route,duration_seconds,wake_check_confirmed"]
        for record in sunrises.sorted(by:{$0.date < $1.date}) {
            let route=(record.steps ?? [CompletedStep(mission:record.mission,amount:record.amount,mode:"guided")]).map {"\($0.mission.title): \($0.amount) \($0.mission.unit) (\($0.mode))"}.joined(separator:"; ")
            lines.append([record.date.ISO8601Format(),record.alarmID.uuidString,record.mood ?? "",route,String(Int(record.durationSeconds ?? 0)),record.wakeCheckConfirmedAt?.ISO8601Format() ?? ""].map(quote).joined(separator:","))
        }
        let file=URL.temporaryDirectory.appending(path:"WakeMeUp-SunriseJournal.csv")
        do {try (lines.joined(separator:"\n")+"\n").write(to:file,atomically:true,encoding:.utf8);return file} catch {self.error="The journal could not be exported.";return nil}
    }
}

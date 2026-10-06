import XCTest
import AVFoundation
@testable import WakeMeUp

@MainActor final class FakeAlarms: AlarmScheduling {
    var authorized = true
    var scheduled: [UUID: WakeAlarm] = [:]
    var failNext = false
    var deny = false
    func enable() async throws { if deny { throw WakeError.message("Denied") } }
    func schedule(_ alarm: WakeAlarm) async throws {
        if failNext { failNext = false; throw WakeError.message("Scheduling failure") }
        scheduled[alarm.id] = alarm
    }
    func cancel(_ id: UUID) throws { scheduled[id] = nil }
    func stop(_ id: UUID) throws {}
}

final class WakeTests: XCTestCase {
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Bucharest")!; return c }
    func date(_ year:Int,_ month:Int,_ day:Int,_ hour:Int = 12,_ minute:Int = 0)->Date { calendar.date(from:DateComponents(year:year,month:month,day:day,hour:hour,minute:minute))! }
    func testWeekdayAndOneShotNextFire() {
        var alarm = WakeAlarm(); alarm.hour = 7; alarm.minute = 0
        XCTAssertEqual(alarm.nextFire(after:date(2026,10,2,8),calendar:calendar), date(2026,10,5,7))
        alarm.weekdays = []
        XCTAssertEqual(alarm.nextFire(after:date(2026,10,2,8),calendar:calendar), date(2026,10,3,7))
    }
    func testSpringForwardDoesNotSkipDay() {
        var alarm=WakeAlarm(); alarm.weekdays=[]; alarm.hour=3; alarm.minute=30
        let next=alarm.nextFire(after:date(2026,3,28,22),calendar:calendar)!
        XCTAssertEqual(calendar.component(.day,from:next),29)
        XCTAssertEqual(calendar.component(.hour,from:next),4)
    }
    func testStreakDuplicatesAndMissedDay() {
        let id=UUID()
        let records=[Sunrise(date:date(2026,10,3),alarmID:id,mission:.dance,amount:30),Sunrise(date:date(2026,10,4),alarmID:id,mission:.dance,amount:30),Sunrise(date:date(2026,10,4,18),alarmID:id,mission:.stretch,amount:30)]
        XCTAssertEqual(Journal.streak(records,now:date(2026,10,5),calendar:calendar),2)
        XCTAssertEqual(Journal.streak(records,now:date(2026,10,6),calendar:calendar),0)
    }
    func testRepCounterRejectsPartialCyclesAndLostTracking() {
        var counter=RepCounter()
        XCTAssertFalse(counter.consume(angle:80,time:0))
        XCTAssertFalse(counter.consume(angle:160,time:1))
        XCTAssertFalse(counter.consume(angle:160,time:2))
        XCTAssertFalse(counter.consume(angle:80,time:3))
        XCTAssertTrue(counter.consume(angle:160,time:4))
        XCTAssertFalse(counter.consume(angle:80,time:4.1))
        XCTAssertFalse(counter.consume(angle:160,time:4.2))
        XCTAssertFalse(counter.consume(angle:nil,time:5))
        XCTAssertFalse(counter.consume(angle:160,time:6))
        XCTAssertEqual(counter.count,1)
    }
    @MainActor func testFailedEditRestoresPriorScheduledAlarm() async {
        let client=FakeAlarms(); let url=URL.temporaryDirectory.appending(path:UUID().uuidString).appending(path:"store.json")
        let store=WakeStore(storageURL:url,alarmClient:client,observe:false)
        var alarm=WakeAlarm(); alarm.label="Original"
        let saved=await store.saveAlarm(alarm,plus:false); XCTAssertTrue(saved)
        var changed=alarm; changed.hour=9; client.failNext=true
        let edited=await store.saveAlarm(changed,plus:false); XCTAssertFalse(edited)
        XCTAssertEqual(client.scheduled[alarm.id]?.hour,7)
        XCTAssertEqual(store.alarms.first?.hour,7)
        let reloaded=WakeStore(storageURL:url,alarmClient:client,observe:false)
        XCTAssertEqual(reloaded.alarms.first?.label,"Original")
    }
    @MainActor func testPermissionDenialAndFreeLimitDoNotSchedule() async {
        let client=FakeAlarms(); let store=WakeStore(storageURL:URL.temporaryDirectory.appending(path:UUID().uuidString).appending(path:"store.json"),alarmClient:client,observe:false)
        client.deny=true
        let denied=await store.saveAlarm(WakeAlarm(),plus:false); XCTAssertFalse(denied); XCTAssertTrue(store.alarms.isEmpty)
        client.deny=false
        let a=await store.saveAlarm(WakeAlarm(),plus:false); let b=await store.saveAlarm(WakeAlarm(),plus:false)
        XCTAssertTrue(a); XCTAssertTrue(b)
        let c=await store.saveAlarm(WakeAlarm(),plus:false); XCTAssertFalse(c)
        XCTAssertEqual(client.scheduled.count,2)
    }
    @MainActor func testPracticeNoCreditAndOneShotCompletion() async {
        let client=FakeAlarms(); let store=WakeStore(storageURL:URL.temporaryDirectory.appending(path:UUID().uuidString).appending(path:"store.json"),alarmClient:client,observe:false)
        var alarm=WakeAlarm(); alarm.weekdays=[]
        _=await store.saveAlarm(alarm,plus:false)
        XCTAssertTrue(store.complete(MorningSession(alarm:alarm,practice:true),mood:nil)); XCTAssertEqual(store.sunrises.count,0)
        XCTAssertTrue(store.complete(MorningSession(alarm:alarm,practice:false),mood:"Bright"))
        XCTAssertFalse(store.alarms[0].enabled)
        XCTAssertTrue(store.complete(MorningSession(alarm:alarm,practice:false),mood:nil)); XCTAssertEqual(store.sunrises.count,1)
    }
}

extension WakeTests {
    func testNextTimeOverrideReplacesRatherThanAddsOccurrence() {
        var alarm=WakeAlarm();alarm.weekdays=Array(1...7);alarm.hour=7;alarm.minute=0
        alarm.nextOverride=date(2026,10,7,6)
        XCTAssertEqual(alarm.occurrences(after:date(2026,10,6,22),count:2,calendar:calendar),[date(2026,10,7,6),date(2026,10,8,7)])
        alarm.nextOverride=date(2026,10,7,9)
        XCTAssertEqual(alarm.occurrences(after:date(2026,10,6,22),count:2,calendar:calendar),[date(2026,10,7,9),date(2026,10,8,7)])
        alarm.skippedDates=[date(2026,10,6),date(2026,10,9)];alarm.pausedUntil=date(2026,10,7,5)
        let cleaned=alarm.removingExpiredExceptions(after:date(2026,10,8,8),calendar:calendar)
        XCTAssertNil(cleaned.nextOverride);XCTAssertNil(cleaned.pausedUntil);XCTAssertEqual(cleaned.skippedDates,[date(2026,10,9)])
    }
    @MainActor func testAudioImportCreatesLocalClipNoLongerThan25Seconds() async throws {
        let source=try XCTUnwrap(Bundle.main.url(forResource:"FirstLight",withExtension:"m4a"))
        let tone=try await ToneLibrary.importAudio(source)
        let file=ToneLibrary.directory.appending(path:tone.id+"Alarm.caf")
        defer {try? FileManager.default.removeItem(at:file)}
        let audio=try AVAudioFile(forReading:file)
        XCTAssertLessThanOrEqual(Double(audio.length)/audio.fileFormat.sampleRate,25.001)
        XCTAssertGreaterThan(Double(audio.length)/audio.fileFormat.sampleRate,24.9)
        XCTAssertEqual(ToneLibrary.alarmFilename(tone.id,gentle:true),tone.id+"Alarm.caf")
        for id in ToneLibrary.builtIn {
            XCTAssertNotNil(ToneLibrary.alarmFilename(id,gentle:false));XCTAssertNotNil(ToneLibrary.alarmFilename(id,gentle:true))
            let preview=try AVAudioFile(forReading:XCTUnwrap(ToneLibrary.previewURL(id)))
            XCTAssertGreaterThan(preview.length,0)
        }
    }
    @MainActor func testFailedDeleteRestoresAlarmAndFollowup() async throws {
        let client=FakeAlarms();let url=URL.temporaryDirectory.appending(path:UUID().uuidString).appending(path:"store.json")
        defer {try? FileManager.default.removeItem(at:url.deletingLastPathComponent())}
        let store=WakeStore(storageURL:url,alarmClient:client,observe:false)
        var alarm=WakeAlarm();alarm.wakeCheckMinutes=3
        _=await store.saveAlarm(alarm,plus:false)
        _=await store.finish(MorningSession(alarm:alarm,practice:false),mood:nil,mode:"guided")
        let check=try XCTUnwrap(store.pendingChecks.first)
        try FileManager.default.removeItem(at:url)
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:false)
        let deleted=await store.delete(alarm)
        XCTAssertFalse(deleted);XCTAssertEqual(store.alarms.count,1)
        XCTAssertNotNil(client.scheduled[alarm.id]);XCTAssertEqual(client.scheduled[check.id]?.datedAt,check.date)
    }
    func testOldVersionDataMigratesWithoutLosingAlarmsOrJournal() throws {
        let legacy = """
        {"alarms":[{"id":"11111111-1111-1111-1111-111111111111","hour":7,"minute":30,"label":"Work","weekdays":[2,3,4,5,6],"mission":"dance","target":30,"tone":"FirstLight","enabled":true}],"sunrises":[{"id":"22222222-2222-2222-2222-222222222222","date":810000000,"alarmID":"11111111-1111-1111-1111-111111111111","mission":"dance","amount":30,"mood":"Bright"}],"soundEnabled":false}
        """
        let value=try JSONDecoder().decode(SavedWake.self,from:Data(legacy.utf8))
        XCTAssertEqual(value.alarms.first?.label,"Work")
        XCTAssertEqual(value.alarms.first?.steps.count,1)
        XCTAssertEqual(value.alarms.first?.scheduleMode,.weekly)
        XCTAssertEqual(value.sunrises.count,1)
        XCTAssertFalse(value.soundEnabled)
        XCTAssertTrue(value.wakeChecks.isEmpty)
        XCTAssertEqual(value.ritualVolume,0.55)
    }
    func testSkippedDateAndPauseResumeWithoutDisablingSeries() {
        var alarm=WakeAlarm();alarm.hour=7;alarm.minute=0
        alarm.skippedDates=[date(2026,10,5)]
        XCTAssertEqual(alarm.nextFire(after:date(2026,10,2,8),calendar:calendar),date(2026,10,6,7))
        alarm.pausedUntil=date(2026,10,8,10)
        XCTAssertEqual(alarm.nextFire(after:date(2026,10,2,8),calendar:calendar),date(2026,10,9,7))
        XCTAssertTrue(alarm.enabled)
    }
    func testRotationUsesCalendarDaysAcrossDST() {
        var alarm=WakeAlarm();alarm.scheduleMode = .rotation;alarm.cycleStart=date(2026,10,24,0)
        alarm.workDays=1;alarm.restDays=1;alarm.hour=7
        let dates=alarm.occurrences(after:date(2026,10,23),count:3,calendar:calendar)
        XCTAssertEqual(dates,[date(2026,10,24,7),date(2026,10,26,7),date(2026,10,28,7)])
    }
    func testDatedAlarmExpiresAndCalendarPlanIsFinite() {
        var alarm=WakeAlarm();alarm.scheduleMode = .dated;alarm.datedAt=date(2026,10,9,8)
        XCTAssertEqual(alarm.occurrences(after:date(2026,10,6),calendar:calendar),[date(2026,10,9,8)])
        XCTAssertNil(alarm.nextFire(after:date(2026,10,10),calendar:calendar))
        alarm.scheduleMode = .rotation;alarm.cycleStart=date(2026,10,6,0)
        XCTAssertEqual(alarm.occurrences(after:date(2026,10,6,0),count:14,calendar:calendar).count,14)
    }
    func testToneRotationAndInstanceIDsAreStable() {
        var alarm=WakeAlarm();alarm.id=UUID(uuidString:"11111111-1111-1111-1111-111111111111")!;alarm.tone="Surprise"
        XCTAssertEqual(alarm.chosenTone(for:date(2026,10,6),calendar:calendar),alarm.chosenTone(for:date(2026,10,6),calendar:calendar))
        XCTAssertNotEqual(alarm.chosenTone(for:date(2026,10,6),calendar:calendar),alarm.chosenTone(for:date(2026,10,7),calendar:calendar))
        XCTAssertEqual(AlarmPlan.instanceID(alarm.id,0),alarm.id)
        XCTAssertEqual(Set((0..<14).map {AlarmPlan.instanceID(alarm.id,$0)}).count,14)
        XCTAssertEqual(AlarmPlan.owner(of:AlarmPlan.instanceID(alarm.id,12),alarms:[alarm])?.id,alarm.id)
    }
    func testIntentionsAndDestinationMatchingDoNotNeedRawSavedCodes() {
        XCTAssertEqual(FocusChallenge.normalized("Today, I’ll START small!"),FocusChallenge.normalized("today ill start small"))
        XCTAssertEqual(FocusChallenge.answer(12,8,operation:1),96)
        XCTAssertEqual(FocusChallenge.answer(12,8,operation:2),4)
        XCTAssertEqual(Destination.hash("kitchen"),Destination.hash("kitchen"))
        XCTAssertNotEqual(Destination.hash("kitchen"),Destination.hash("bathroom"))
        XCTAssertFalse(Destination.hash("kitchen").contains("kitchen"))
    }
    @MainActor func testRouteCheckpointsRecoverAndPracticeStillEarnsNoCredit() async throws {
        let client=FakeAlarms();let url=URL.temporaryDirectory.appending(path:UUID().uuidString).appending(path:"store.json")
        let store=WakeStore(storageURL:url,alarmClient:client,observe:false)
        var alarm=WakeAlarm();alarm.route=[RitualStep(mission:.math),RitualStep(mission:.daylight)]
        _=await store.saveAlarm(alarm,plus:false)
        store.begin(alarm,practice:false);let first=try XCTUnwrap(store.session)
        store.advance(first,mode:"guided")
        let reloaded=WakeStore(storageURL:url,alarmClient:client,observe:false);reloaded.resumePending()
        XCTAssertEqual(reloaded.session?.stepIndex,1)
        XCTAssertEqual(reloaded.session?.completedSteps.count,1)
        let final=try XCTUnwrap(reloaded.session)
        let finished=await reloaded.finish(final,mood:"Bright",mode:"self-reported action")
        XCTAssertTrue(finished);XCTAssertEqual(reloaded.sunrises.first?.steps?.count,2)
        let before=reloaded.sunrises.count
        let practice=MorningSession(alarm:alarm,practice:true)
        let practiced=await reloaded.finish(practice,mood:nil,mode:"guided")
        XCTAssertTrue(practiced);XCTAssertEqual(reloaded.sunrises.count,before)
    }
    @MainActor func testWakeCheckIsScheduledAndConfirmationUpdatesExistingSunrise() async throws {
        let client=FakeAlarms();let store=WakeStore(storageURL:URL.temporaryDirectory.appending(path:UUID().uuidString).appending(path:"store.json"),alarmClient:client,observe:false)
        var alarm=WakeAlarm();alarm.wakeCheckMinutes=3
        _=await store.saveAlarm(alarm,plus:false)
        let result=await store.finish(MorningSession(alarm:alarm,practice:false),mood:nil,mode:"guided")
        XCTAssertTrue(result)
        let check=try XCTUnwrap(store.pendingChecks.first)
        XCTAssertTrue(client.scheduled[check.id]?.isOneShot ?? false)
        XCTAssertEqual(store.sunrises.count,1)
        XCTAssertTrue(store.confirmAwake(check))
        XCTAssertNotNil(store.sunrises.first?.wakeCheckConfirmedAt)
        XCTAssertEqual(store.sunrises.count,1);XCTAssertTrue(store.pendingChecks.isEmpty)
        XCTAssertNil(client.scheduled[check.id])
    }
    @MainActor func testFailedSkipRestoresAlarmAndDoesNotCommitException() async {
        let client=FakeAlarms();let store=WakeStore(storageURL:URL.temporaryDirectory.appending(path:UUID().uuidString).appending(path:"store.json"),alarmClient:client,observe:false)
        let alarm=WakeAlarm();_=await store.saveAlarm(alarm,plus:false);client.failNext=true
        await store.skipNext(alarm,plus:false)
        XCTAssertTrue(store.alarms.first?.skippedDates.isEmpty ?? false)
        XCTAssertEqual(client.scheduled[alarm.id]?.skippedDates,[])
    }
    @MainActor func testQuickNapReplacesOnlyNapAndDoesNotUseSavedAlarmLimit() async {
        let client=FakeAlarms();let store=WakeStore(storageURL:URL.temporaryDirectory.appending(path:UUID().uuidString).appending(path:"store.json"),alarmClient:client,observe:false)
        _=await store.saveAlarm(WakeAlarm(),plus:false);_=await store.saveAlarm(WakeAlarm(),plus:false)
        await store.quickNap(minutes:20,plus:false);await store.quickNap(minutes:30,plus:false)
        XCTAssertEqual(store.alarms.filter(\.isNap).count,1)
        XCTAssertEqual(store.alarms.filter {!$0.isNap}.count,2)
        XCTAssertEqual(client.scheduled.count,3)
    }
    @MainActor func testJournalExportQuotesFieldsAndIncludesCheckIn() async throws {
        let client=FakeAlarms();let store=WakeStore(storageURL:URL.temporaryDirectory.appending(path:UUID().uuidString).appending(path:"store.json"),alarmClient:client,observe:false)
        let alarm=WakeAlarm();_=await store.saveAlarm(alarm,plus:false)
        XCTAssertTrue(store.complete(MorningSession(alarm:alarm,practice:false),mood:"Okay"))
        let file=try XCTUnwrap(store.exportJournal());let text=try String(contentsOf:file,encoding:.utf8)
        XCTAssertTrue(text.contains("wake_check_confirmed"));XCTAssertTrue(text.contains("\"Okay\""))
        XCTAssertEqual(text.split(separator:"\n").count,2)
    }
}

import XCTest
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

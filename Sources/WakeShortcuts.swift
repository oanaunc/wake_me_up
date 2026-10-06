import AppIntents
import Foundation

enum PracticeRoute:String,AppEnum {
    case gentle,focus,joy
    static var typeDisplayRepresentation:TypeDisplayRepresentation = "Morning route"
    static var caseDisplayRepresentations:[PracticeRoute:DisplayRepresentation] = [.gentle:"Gentle start",.focus:"Focus and feet",.joy:"Tiny joy"]
}
struct QuickNapIntent:AppIntent {
    static var title:LocalizedStringResource = "Set a quick nap"
    static var description=IntentDescription("Open Wake Me Up and schedule a local nap alarm.")
    static var openAppWhenRun=true
    @Parameter(title:"Minutes",default:20) var minutes:Int
    @MainActor func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(min(180,max(1,minutes)),forKey:"pendingNapMinutes")
        NotificationCenter.default.post(name:.init("wake.beginMorning"),object:nil)
        return .result()
    }
}
struct PracticeRouteIntent:AppIntent {
    static var title:LocalizedStringResource = "Practice a morning route"
    static var description=IntentDescription("Practice a short route without adding journal credit.")
    static var openAppWhenRun=true
    @Parameter(title:"Route",default:.gentle) var route:PracticeRoute
    @MainActor func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(route.rawValue,forKey:"pendingPractice")
        NotificationCenter.default.post(name:.init("wake.beginMorning"),object:nil)
        return .result()
    }
}
struct NextWakeUpIntent:AppIntent {
    static var title:LocalizedStringResource = "Check my next wake-up"
    static var description=IntentDescription("Read your next enabled Wake Me Up alarm.")
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store=WakeStore.liveStore ?? WakeStore(observe:false)
        let next=store.alarms.filter(\.enabled).compactMap {alarm -> (WakeAlarm,Date)? in guard let date=alarm.nextFire(after:.now) else {return nil};return(alarm,date)}.min {$0.1 < $1.1}
        if let next {
            if next.0.usesCalendarPlan && next.1 > (store.saved.plannedThrough[next.0.id.uuidString] ?? .distantPast) {
                return .result(dialog:"Your calendar plan needs a refill. Open Wake Me Up to schedule more dates.")
            }
            return .result(dialog:"Your next wake-up is \(next.0.label), \(next.1.formatted(date:.abbreviated,time:.shortened)).")
        }
        return .result(dialog:"You have no enabled Wake Me Up alarm.")
    }
}
struct WakeShortcuts:AppShortcutsProvider {
    static var appShortcuts:[AppShortcut] {
        AppShortcut(intent:QuickNapIntent(),phrases:["Set a nap with \(.applicationName)"],shortTitle:"Quick nap",systemImageName:"moon.zzz")
        AppShortcut(intent:PracticeRouteIntent(),phrases:["Practice with \(.applicationName)"],shortTitle:"Practice a route",systemImageName:"sun.max")
        AppShortcut(intent:NextWakeUpIntent(),phrases:["Check my alarm in \(.applicationName)"],shortTitle:"Next wake-up",systemImageName:"alarm")
    }
}

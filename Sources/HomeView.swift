import SwiftUI

struct HomeView: View {
    @Environment(WakeStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var editing: WakeAlarm?
    @State private var showPlus = false
    var next: WakeAlarm? { store.alarms.filter(\.enabled).min { ($0.nextFire(after: .now) ?? .distantFuture) < ($1.nextFire(after: .now) ?? .distantFuture) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        DawnHeading(eyebrow: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()), title: "Hello, sunshine.", subtitle: "A small move. A brighter morning.")
                        if sizeClass == .regular && !store.hideStreak { Label("\(store.streak) day streak", systemImage: "sun.max.fill").font(.subheadline.bold()).dawnCard(Dawn.peach) }
                    }
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-alarm-integration"), store.alarms.isEmpty {
                        Button("Schedule integration alarm") {
                            Task {
                                var alarm = WakeAlarm(); alarm.label = "Integration sunrise"; alarm.mission = .sunTaps; alarm.target = 8; alarm.weekdays = []
                                if ProcessInfo.processInfo.arguments.contains("-snooze-integration") {alarm.snoozeMinutes=3}
                                if ProcessInfo.processInfo.arguments.contains("-check-integration") {alarm.wakeCheckMinutes=3}
                                _ = await store.saveAlarm(alarm, plus: false)
                            }
                        }.accessibilityIdentifier("schedule-integration")
                    }
                    #endif
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 24) { sunriseCard.frame(maxWidth: .infinity); alarmSection.frame(maxWidth: .infinity) }
                    } else { sunriseCard; alarmSection }
                    NavigationLink {MorningToolsView()} label: {
                        HStack {Label("Morning tools",systemImage:"moon.zzz");Spacer();Text("Naps · days off · bedside").font(.caption);Image(systemName:"chevron.right")}
                            .font(.subheadline.bold()).foregroundStyle(Dawn.ink).dawnCard(Dawn.green)
                    }.accessibilityIdentifier("morning-tools")
                    if !store.pendingChecks.isEmpty {
                        ForEach(store.pendingChecks) {check in HStack {
                            Label("Wake-up check · \(check.date.formatted(date:.omitted,time:.shortened))",systemImage:"sun.max")
                            Spacer();Button("Cancel") {store.cancelCheck(check)}
                        }.font(.caption).dawnCard()}
                    }
                    HStack { Text("Find your morning rhythm").font(Dawn.title(22)); Spacer() }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 230 : 150), spacing: 14)], spacing: 14) {
                        ForEach(Mission.allCases) { mission in MissionTile(mission: mission) { var alarm = WakeAlarm(); alarm.mission = mission; alarm.target = mission.defaultTarget; store.begin(alarm, practice: true) } }
                    }
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles").font(.title2)
                        VStack(alignment: .leading, spacing: 4) { Text("Your morning, with more possibilities.").font(.subheadline.bold()); Text("Meet Wake Me Up Plus").font(.caption).foregroundStyle(Dawn.muted) }
                        Spacer(); Image(systemName: "chevron.right")
                    }.dawnCard().contentShape(Rectangle()).onTapGesture { showPlus = true }.accessibilityAddTraits(.isButton)
                }.padding(24).frame(maxWidth: 1150).frame(maxWidth: .infinity)
            }.background(Dawn.cream).toolbar(.hidden, for: .navigationBar)
                .sheet(item: $editing) { alarm in AlarmEditor(alarm: alarm) }
                .sheet(isPresented: $showPlus) { PlusView() }
        }
    }
    var sunriseCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Artwork(name: "SunriseLandscape").frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 24)).overlay(alignment: .topLeading) {
                Label("YOUR NEXT SUNRISE", systemImage: "sun.horizon").font(.caption2.bold()).tracking(1.5).padding(12).background(Dawn.cream.opacity(0.9), in: Capsule()).padding(16)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(next?.nextFire(after:.now)?.formatted(date:.omitted,time:.shortened) ?? "A fresh start.").font(Dawn.title(next == nil ? 32 : 48)).minimumScaleFactor(0.7)
                    Spacer()
                    if let next { Image(systemName: next.mission.symbol).font(.title).padding(12).background(Dawn.tint(next.mission), in: Circle()) }
                }
                if let next {
                    Text("\(next.label) · \(next.repeatText)").font(.subheadline).foregroundStyle(Dawn.muted)
                    Label(next.routeText,systemImage:"point.topleft.down.to.point.bottomright.curvepath").font(.subheadline.bold())
                    if let fire=next.nextFire(after:.now) {
                        Text(fire.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.caption).foregroundStyle(Dawn.muted)
                        Text("Wind down around \(fire.addingTimeInterval(-store.saved.sleepGoalHours*3600).formatted(date:.omitted,time:.shortened)) for your \(store.saved.sleepGoalHours.formatted())-hour rest goal.").font(.caption).foregroundStyle(Dawn.muted)
                    }
                } else { Text("Set an alarm tonight. Meet a brighter you tomorrow.").font(.subheadline).foregroundStyle(Dawn.muted) }
                DawnButton(title: next == nil ? "Set my first alarm" : "Edit my morning", symbol: "plus") { editing = next ?? WakeAlarm() }.padding(.top, 8).accessibilityIdentifier("add-first-alarm")
                if !store.alarmAccess && store.alarms.contains(where: \.enabled) { Text("Alarm access is off. Re-enable it in Settings before relying on an alarm.").font(.caption.bold()).foregroundStyle(Dawn.orange) }
            }.padding(22)
        }.background(.white, in: RoundedRectangle(cornerRadius: 28)).overlay(RoundedRectangle(cornerRadius: 28).stroke(Dawn.ink.opacity(0.06))).foregroundStyle(Dawn.ink)
    }
    var alarmSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Your alarms").font(Dawn.title(22)); Spacer(); Button { if store.alarms.filter {!$0.isNap}.count >= 2 && !purchases.hasPlus { showPlus = true } else { editing = WakeAlarm() } } label: { Image(systemName: "plus").font(.body.bold()).frame(width: 44, height: 44).background(.white,in: Circle()) }.accessibilityLabel("Add alarm").accessibilityIdentifier("add-alarm") }
            if store.alarms.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Start with something small", systemImage: "moon.stars").font(.headline)
                    Text("Five push-ups. Thirty seconds of dancing. A gentle stretch. Choose what feels like you.").font(.subheadline).foregroundStyle(Dawn.muted)
                }.frame(maxWidth: .infinity, alignment: .leading).dawnCard()
            }
            ForEach(store.alarms) { alarm in
                VStack(alignment:.leading,spacing:12) {
                HStack(spacing: 12) {
                    Button { editing = alarm } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(alarm.timeText).font(Dawn.title(32)).foregroundStyle(alarm.enabled ? Dawn.ink : Dawn.muted)
                            Text("\(alarm.label) · \(alarm.repeatText)").font(.caption).foregroundStyle(Dawn.muted)
                            Label(alarm.routeText, systemImage: alarm.mission.symbol).font(.caption.bold()).foregroundStyle(Dawn.ink)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain).accessibilityLabel("Edit \(alarm.label), \(alarm.timeText)")
                    Toggle("Alarm enabled", isOn: Binding(get: { alarm.enabled }, set: { enabled in var copy = alarm; copy.enabled = enabled; Task { _ = await store.saveAlarm(copy, plus: purchases.hasPlus) } })).labelsHidden().tint(Dawn.orange).disabled(store.busy)
                }
                if alarm.enabled {
                    if let next=alarm.nextFire(after:.now) {Text("Next: \(next.formatted(date:.abbreviated,time:.shortened))").font(.caption).foregroundStyle(Dawn.muted)}
                    HStack {
                        Button("Skip next") {Task {await store.skipNext(alarm,plus:purchases.hasPlus)}}.accessibilityIdentifier("skip-next-alarm")
                        Spacer()
                        if let through=store.saved.plannedThrough[alarm.id.uuidString] {Text("Scheduled through \(through.formatted(.dateTime.month(.abbreviated).day()))").font(.caption2).foregroundStyle(Dawn.muted)}
                    }.font(.caption.bold()).disabled(store.busy)
                }
                }.dawnCard()
            }
            Label("System alarms work when the app is closed.", systemImage: "checkmark.shield").font(.caption).foregroundStyle(Dawn.muted)
            Text("Open the movement action to start your ritual. iOS keeps its own dismissal controls.").font(.caption).foregroundStyle(Dawn.muted)
        }.foregroundStyle(Dawn.ink)
    }
}

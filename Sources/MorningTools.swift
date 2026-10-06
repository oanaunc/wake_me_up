import SwiftUI
import AVFoundation
import UserNotifications

struct MorningToolsView:View {
    @Environment(WakeStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @State private var nightstand=false
    @State private var pauseDate=Date.now.addingTimeInterval(86400)
    @State private var napMinutes=20
    @State private var pauseSaved=false
    var body:some View {
        Form {
            Section {
                DawnHeading(eyebrow:"Make waking up easier",title:"Little morning tools.",subtitle:"Short rests, a calmer bedside view, and clear checks before you rely on an alarm.")
            }.listRowBackground(Color.clear)
            Section("A quick nap") {
                Picker("Rest for",selection:$napMinutes) {ForEach([10,15,20,30,45,60,90],id:\.self) {Text("\($0) minutes").tag($0)}}
                Button("Set a \(napMinutes)-minute nap",systemImage:"moon.zzz") {Task {await store.quickNap(minutes:napMinutes,plus:purchases.hasPlus)}}
                    .disabled(store.busy).accessibilityIdentifier("set-quick-nap")
                if let nap=store.alarms.first(where:{$0.isNap && $0.enabled}) {Label("Nap alarm: \(nap.datedAt.formatted(date:.omitted,time:.shortened))",systemImage:"checkmark.circle")}
                Text("One quick nap in addition to your saved alarms. Setting another nap replaces the previous nap.").font(.caption).foregroundStyle(Dawn.muted)
            }
            Section("Time off") {
                DatePicker("Pause alarms until",selection:$pauseDate,in:Date.now...,displayedComponents:[.date,.hourAndMinute])
                Button("Pause my enabled alarms") {Task {pauseSaved=await store.pauseAll(until:pauseDate,plus:purchases.hasPlus)}}
                    .disabled(store.busy || store.alarms.allSatisfy {!$0.enabled})
                if pauseSaved {Text("Pause saved. Your next wake-ups appear on Morning.").font(.caption)}
                Text("The next 14 dates after the pause are saved with the system. Open the app to refill special calendar plans. You can end the pause in each alarm editor.").font(.caption).foregroundStyle(Dawn.muted)
            }
            Section("Before bed") {
                Button("Open bedside clock",systemImage:"clock") {nightstand=true}
                NavigationLink("Alarm readiness check") {AlarmReadinessView()}
                NavigationLink("Saved destination codes") {DestinationsView()}
                Text("The bedside view is optional. Native system alarms do not need it open to ring.").font(.caption).foregroundStyle(Dawn.muted)
            }
        }.scrollContentBackground(.hidden).background(Dawn.cream).navigationTitle("Morning tools").navigationBarTitleDisplayMode(.inline).toolbar(.visible,for:.navigationBar)
            .fullScreenCover(isPresented:$nightstand) {BedsideClockView()}
    }
}
struct AlarmReadinessView:View {
    @Environment(WakeStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.openURL) private var openURL
    @State private var heardTest=false
    var body:some View {
        Form {
            Section("On this device") {
                Label(store.alarmAccess ? "Native alarm access is allowed" : "Native alarm access is not allowed",systemImage:store.alarmAccess ? "checkmark.circle.fill" : "exclamationmark.circle")
                Button("Open app permissions") {openURL(URL(string:UIApplication.openSettingsURLString)!)}
                Text("Keep the device powered on. iOS controls system alarm volume and sound routing. The ritual music slider does not change alarm volume.").font(.subheadline).foregroundStyle(Dawn.muted)
            }
            Section("Try a real alarm") {
                Button("Schedule a one-minute sound test") {Task {await store.quickNap(minutes:1,plus:purchases.hasPlus)}}.disabled(store.busy)
                Text("This uses the quick-nap slot. Lock the device and confirm that its system alarm rings. Try Silent mode and Focus too; listen on the actual device.").font(.caption).foregroundStyle(Dawn.muted)
                Toggle("I heard the alarm on this device",isOn:$heardTest).tint(Dawn.orange)
                Text("This is your own checklist, not an automatic hardware test result.").font(.caption).foregroundStyle(Dawn.muted)
            }
            Section("Optional counting") {
                Label(AVCaptureDevice.authorizationStatus(for:.video) == .authorized ? "Camera access allowed" : "Camera is optional · guided mode works",systemImage:"camera")
                Text("Try camera counting from a secure side view. For dance or marching, try gentle movement with the phone securely held. Switch to guided counting if estimates are unreliable.").font(.subheadline).foregroundStyle(Dawn.muted)
            }
            Section("Calendar plans") {
                ForEach(store.alarms.filter {$0.enabled && $0.usesCalendarPlan}) {alarm in
                    VStack(alignment:.leading,spacing:4) {
                        Text(alarm.label).font(.headline)
                        if let through=store.saved.plannedThrough[alarm.id.uuidString] {Text("Scheduled through \(through.formatted(date:.abbreviated,time:.shortened))").font(.caption)}
                    }
                }
                Text("Weekly repeats keep running. Rotations, sound changes, pauses, and exceptions use 14 pre-scheduled dates and refill when you open the app. Dates beyond the shown horizon are not scheduled.").font(.caption).foregroundStyle(Dawn.muted)
                Button("Refresh calendar plans") {Task {await store.refreshSchedules()}}.disabled(store.busy)
            }
        }.scrollContentBackground(.hidden).background(Dawn.cream).navigationTitle("Alarm readiness").toolbar(.visible,for:.navigationBar)
    }
}
struct BedsideClockView:View {
    @Environment(WakeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var dim=false
    var body:some View {
        TimelineView(.periodic(from:.now,by:1)) {context in
            VStack(spacing:24) {
                HStack {Button("Close") {dismiss()};Spacer();Button(dim ? "Brighter" : "Dim") {dim.toggle()}}
                Spacer()
                Text(context.date.formatted(date:.omitted,time:.shortened)).font(.system(size:88,weight:.light,design:.rounded)).minimumScaleFactor(0.4).lineLimit(1).monospacedDigit()
                Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.title3)
                if let next=store.alarms.filter(\.enabled).min(by:{($0.nextFire(after:.now) ?? .distantFuture) < ($1.nextFire(after:.now) ?? .distantFuture)}),let fire=next.nextFire(after:.now) {
                    Label("\(next.label) · \(fire.formatted(date:.abbreviated,time:.shortened))",systemImage:"alarm").font(.subheadline)
                } else {Text("No enabled alarm")}
                Spacer()
                Text("Native alarms keep working when this view is closed.").font(.caption).multilineTextAlignment(.center)
            }.padding(32).frame(maxWidth:.infinity,maxHeight:.infinity).foregroundStyle(dim ? Color.gray : Dawn.peach).background(Color(red:0.07,green:0.05,blue:0.08)).ignoresSafeArea(edges:.bottom)
        }.onAppear {UIApplication.shared.isIdleTimerDisabled=true}
            .onDisappear {UIApplication.shared.isIdleTimerDisabled=false}
            .onChange(of:phase) {_,phase in UIApplication.shared.isIdleTimerDisabled=phase == .active}
    }
}

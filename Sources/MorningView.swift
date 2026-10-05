import SwiftUI
import UIKit
import Combine

struct MorningView: View {
    var session: MorningSession
    @Environment(WakeStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var sensor = MovementSensor()
    @State private var audio = MorningAudio()
    @State private var started = false
    @State private var progress = 0.0
    @State private var reps = 0
    @State private var lastTick: Date?
    @State private var finished = false
    @State private var mood: String?
    @State private var exit = false
    @State private var saveError: String?
    @State private var muted = false
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    var target: Int { session.alarm.target }
    var amount: Int { session.alarm.mission.isCounted ? reps : Int(progress) }
    var fraction: Double { min(1, Double(amount) / Double(target)) }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        Text(session.practice ? "A LITTLE PRACTICE" : "YOUR MORNING RITUAL").font(.caption.bold()).tracking(2).foregroundStyle(Dawn.orange)
                        Spacer()
                        Button { muted.toggle(); if muted { audio.stop() } else if started { audio.play(tone: session.alarm.tone, enabled: store.soundEnabled) } } label: { Image(systemName: muted ? "speaker.slash" : "speaker.wave.2").frame(width: 44,height: 44) }.accessibilityLabel(muted ? "Unmute music" : "Mute music")
                        Button { if finished { dismiss() } else { exit = true } } label: { Image(systemName: "xmark").frame(width: 44,height: 44) }.accessibilityLabel("Exit ritual")
                    }
                    if finished { completion }
                    else {
                        Text(started ? "Here comes your sun." : session.alarm.mission.title).font(Dawn.title(34)).multilineTextAlignment(.center)
                        ZStack(alignment: .bottom) {
                            Circle().fill(Dawn.tint(session.alarm.mission)).frame(width: 240,height: 240)
                            Artwork(name: "SunMascot").frame(width: 250,height: 250).clipShape(Circle()).offset(y: reduceMotion ? 0 : (1 - fraction) * 28)
                        }.frame(height: 270).animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: amount)
                        if sensor.cameraActive { CameraPreview(session: sensor.capture.session).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 22)).overlay(alignment: .bottom) { Text("On-device only · no recording").font(.caption.bold()).padding(10).background(Dawn.cream.opacity(0.9),in: Capsule()).padding(10) } }
                        if started {
                            VStack(spacing: 10) {
                                Text("\(amount) / \(target)").font(Dawn.title(58)).monospacedDigit().accessibilityIdentifier("ritual-progress")
                                Text(session.alarm.mission.unit.uppercased()).font(.caption.bold()).tracking(3).foregroundStyle(Dawn.muted)
                                ProgressView(value: fraction).tint(Dawn.orange).padding(.horizontal, 40)
                                Text(sensor.cameraActive || sensor.motionActive ? sensor.status : session.alarm.mission.isCounted ? session.alarm.mission.countingHint : stretchCue).font(.subheadline).foregroundStyle(Dawn.muted).multilineTextAlignment(.center)
                            }
                            if session.alarm.mission == .sunTaps {
                                sunTapGrid
                            } else if session.alarm.mission.isCounted {
                                if !sensor.cameraActive { DawnButton(title: session.alarm.mission == .pushups ? "One push-up done" : "One squat done", symbol: "plus") { reps = min(target,reps + 1); checkComplete() }.accessibilityIdentifier("count-rep") }
                            } else { DawnButton(title: "Pause for a breath", symbol: "pause") { pause() } }
                            if sensor.cameraActive || sensor.motionActive { Button("Switch to guided mode") { sensor.stop() }.font(.subheadline.bold()) }
                        } else {
                            Text(session.alarm.mission.instructions).font(.body).foregroundStyle(Dawn.muted).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                            DawnButton(title: progress > 0 || reps > 0 ? "Continue my morning" : "Start in guided mode", symbol: "play.fill") { start() }.accessibilityIdentifier("start-guided")
                            if session.alarm.mission == .pushups { Button("Use camera counting") { Task { await sensor.camera(); if sensor.cameraActive { start() } } }.font(.body.bold()).padding(6) }
                            if session.alarm.mission.supportsMotion { Button("Use motion counting") { sensor.dance(); if sensor.motionActive { start() } }.font(.body.bold()).padding(6) }
                            if sensor.status != "Ready when you are" { Text(sensor.status).font(.caption).foregroundStyle(Dawn.orange).multilineTextAlignment(.center) }
                        }
                        Text("Move only if it feels comfortable. Stop anytime. Guided mode uses your own count or an active timer; sensors estimate movement.").font(.caption).foregroundStyle(Dawn.muted).multilineTextAlignment(.center)
                        Button("Choose a gentle stretch instead") { pause(); var gentle = session; gentle.alarm.mission = .stretch; gentle.alarm.target = 30; store.session = gentle }.font(.caption.bold())
                    }
                }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity).frame(minHeight: geometry.size.height)
            }.background(Dawn.cream).foregroundStyle(Dawn.ink)
        }
        .onReceive(timer) { now in
            defer { lastTick = now }
            guard started, !finished, phase == .active, let previous = lastTick, !session.alarm.mission.isCounted else { return }
            if !sensor.motionActive || sensor.moving { progress = min(Double(target), progress + min(0.2,now.timeIntervalSince(previous))); checkComplete() }
        }
        .onChange(of: sensor.count) { old, count in if started { reps = min(target,reps + max(0,count - old)); checkComplete() } }
        .onChange(of: phase) { _, state in if state != .active { pause() } }
        .onDisappear { sensor.stop(); audio.stop(); UIApplication.shared.isIdleTimerDisabled = false }
        .confirmationDialog("Your morning, your choice", isPresented: $exit, titleVisibility: .visible) { Button("Exit without saving a sunrise", role: .destructive) { pause(); store.abandon(); dismiss() }; Button("Keep going", role: .cancel) {} } message: { Text("The alarm has stopped. You can safely leave the ritual anytime.") }
        .alert("Morning not saved", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) { Button("OK") { saveError = nil } } message: { Text(saveError ?? "") }
    }
    var stretchCue: String {
        if session.alarm.mission == .dance { return "Your move. Your rhythm. Keep it gentle." }
        if session.alarm.mission == .march { return "Small steps or seated heel lifts. Find your easy pace." }
        if session.alarm.mission == .breathe { return amount % 10 < 4 ? "Breathe in gently · 4 seconds" : "Breathe out slowly · 6 seconds" }
        let third = max(1, target / 3)
        return amount < third ? "Slowly roll your shoulders and breathe." : amount < third * 2 ? "Reach gently upward, seated or standing." : "Relax your arms. Welcome the day."
    }
    var sunTapGrid: some View {
        let spot = [0,3,1,2][reps % 4]
        return LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())],spacing: 12) {
            ForEach(0..<4) { index in
                Button { guard index == spot else { return }; reps = min(target,reps + 1); checkComplete() } label: {
                    Image(systemName: index == spot ? "sun.max.fill" : "circle.dotted").font(.system(size: 32)).frame(maxWidth:.infinity).frame(height: 82).foregroundStyle(index == spot ? Dawn.orange : Dawn.muted.opacity(0.3)).background(index == spot ? Dawn.peach : .white,in:RoundedRectangle(cornerRadius:20))
                }.buttonStyle(.plain).disabled(index != spot).accessibilityLabel(index == spot ? "Tap the sun" : "Empty spot").accessibilityIdentifier(index == spot ? "sun-target" : "sun-empty")
            }
        }
    }
    var completion: some View {
        VStack(spacing: 24) {
            Artwork(name: "SunMascot").frame(width: 260,height: 260).clipShape(Circle())
            Text("You brought\nthe sunshine.").font(Dawn.title(42)).multilineTextAlignment(.center)
            Text(session.practice ? "A little practice is a lovely start. Your streak grows when you complete an alarm ritual." : "One small promise to yourself, kept.\nHow does your morning feel?").foregroundStyle(Dawn.muted).multilineTextAlignment(.center)
            if !session.practice {
                HStack { ForEach(["Sleepy", "Okay", "Bright"], id: \.self) { item in Button { mood = item } label: { Text(item).font(.subheadline.bold()).frame(maxWidth: .infinity).padding(14).background(mood == item ? Dawn.peach : .white, in: Capsule()) }.buttonStyle(.plain) } }
            }
            DawnButton(title: session.practice ? "Back to my morning" : "Save my sunrise", symbol: "sun.max.fill") {
                if store.complete(session,mood: mood) { dismiss() }
                else { saveError = store.error; store.error = nil }
            }.accessibilityIdentifier("save-sunrise")
        }
    }
    func start() { started = true; lastTick = .now; UIApplication.shared.isIdleTimerDisabled = true; if !muted { audio.play(tone: session.alarm.tone, enabled: store.soundEnabled) } }
    func pause() { started = false; lastTick = nil; sensor.stop(); audio.stop(); UIApplication.shared.isIdleTimerDisabled = false }
    func checkComplete() { if amount >= target { finished = true; pause(); UINotificationFeedbackGenerator().notificationOccurred(.success) } }
}

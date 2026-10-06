import SwiftUI

@main
struct WakeMeUpApp: App {
    @State private var store: WakeStore = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-alarm-integration") { return WakeStore(storageURL: URL.applicationSupportDirectory.appending(path: "wake-integration.json")) }
        #endif
        return WakeStore()
    }()
    @State private var purchases = PurchaseStore()
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(purchases).tint(Dawn.ink).preferredColorScheme(.light)
                .task { await purchases.load() }
        }
    }
}

struct RootView: View {
    @Environment(WakeStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @AppStorage("welcomed") private var welcomed = false
    @State private var tab = 0
    var body: some View {
        @Bindable var store = store
        TabView(selection: $tab) {
            Tab("Morning", systemImage: "sun.max", value: 0) { HomeView() }
            Tab("Move", systemImage: "figure.dance", value: 1) { RoutinesView() }
            Tab("Sunrises", systemImage: "calendar", value: 2) { JournalView() }
            Tab("Settings", systemImage: "slider.horizontal.3", value: 3) { SettingsView() }
        }
        .fullScreenCover(isPresented: Binding(get: { !welcomed }, set: { if !$0 { welcomed = true } })) {
            WelcomeView { welcomed = true }
        }
        .fullScreenCover(item: $store.session) { session in MorningView(session: session).id("\(session.id)-\(session.stepIndex)-\(session.currentStep.mission.rawValue)") }
        .fullScreenCover(item:$store.awakeCheck) {check in AwakeCheckView(check:check)}
        .alert("A little attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
        .onChange(of: phase) { _, state in if state == .active { store.resumePending();Task {await store.refreshSchedules()} } }
        .onChange(of: welcomed) { _, ready in if ready { store.resumePending() } }
        .task {
            if welcomed { store.resumePending();await store.refreshSchedules() }
        }
    }
}

struct WelcomeView: View {
    var done: () -> Void
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    Text("WAKE ME UP").font(.caption.bold()).tracking(4).padding(.top, 28)
                    Artwork(name: "SunriseLandscape").frame(maxWidth: 650).clipShape(RoundedRectangle(cornerRadius: 32))
                    VStack(spacing: 12) {
                        Text("Bring your\nsunshine back.").font(Dawn.title(44)).multilineTextAlignment(.center)
                        Text("An alarm. A little movement.\nA morning that starts with you.").font(.title3).foregroundStyle(Dawn.muted).multilineTextAlignment(.center)
                    }
                    VStack(alignment: .leading, spacing: 15) {
                        Label("Push up, dance, or stretch gently", systemImage: "figure.dance")
                        Label("Optional camera counting stays on device", systemImage: "lock.shield")
                        Label("No account. No ads. Your own pace.", systemImage: "heart")
                    }.font(.subheadline).padding(.vertical, 10)
                    DawnButton(title: "Make room for morning", symbol: "sun.max.fill", action: done).accessibilityIdentifier("welcome-start")
                    Text("iOS can always dismiss a system alarm. Open Wake Me Up to complete your movement ritual.").font(.caption).foregroundStyle(Dawn.muted).multilineTextAlignment(.center)
                }.foregroundStyle(Dawn.ink).padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity).frame(minHeight: geometry.size.height)
            }.background(Dawn.cream)
        }
    }
}

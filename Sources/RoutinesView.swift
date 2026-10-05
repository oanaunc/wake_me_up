import SwiftUI

struct RoutinesView: View {
    @Environment(WakeStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @State private var plus = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DawnHeading(eyebrow: "Movement menu", title: "Start small. Feel good.", subtitle: "Find your rhythm before the alarm rings. Practice never changes your sunrise streak.")
                    ForEach(Mission.allCases) { mission in
                        VStack(alignment: .leading, spacing: 16) {
                            HStack { Image(systemName: mission.symbol).font(.system(size: 38)); Spacer(); Text("\(mission.defaultTarget) \(mission.unit)").font(.caption.bold()).padding(10).background(.white.opacity(0.7),in: Capsule()) }
                            Text(mission.title).font(Dawn.title(28))
                            Text(mission.countingHint).font(.caption.bold()).foregroundStyle(Dawn.orange)
                            Text(mission.instructions).font(.subheadline).foregroundStyle(Dawn.muted).fixedSize(horizontal: false,vertical: true)
                            DawnButton(title: "Try \(mission.title.lowercased())", symbol: "play.fill") { var alarm = WakeAlarm(); alarm.mission = mission; alarm.target = mission.defaultTarget; store.begin(alarm, practice: true) }.accessibilityIdentifier("practice-\(mission.rawValue)")
                        }.dawnCard(Dawn.tint(mission))
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Label("A longer little ritual",systemImage: "sparkles").font(Dawn.title(24))
                        Text("Plus lets you choose up to 30 reps or sun taps, or 3 minutes of a timed challenge. Keep your goal comfortable and achievable.").font(.subheadline).foregroundStyle(Dawn.muted)
                        DawnButton(title: purchases.hasPlus ? "Practice a 60-second dance" : "Explore Plus", symbol: "arrow.up.right") { if purchases.hasPlus { var alarm = WakeAlarm(); alarm.target = 60; store.begin(alarm,practice: true) } else { plus = true } }
                    }.dawnCard()
                }.padding(24).frame(maxWidth: 900).frame(maxWidth: .infinity)
            }.background(Dawn.cream).toolbar(.hidden,for: .navigationBar).foregroundStyle(Dawn.ink).sheet(isPresented: $plus) { PlusView() }
        }
    }
}

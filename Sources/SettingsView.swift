import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(WakeStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.openURL) private var openURL
    @State private var plus = false
    @State private var manage = false
    @State private var clear = false
    var body: some View {
        NavigationStack {
            Form {
                Section { DawnHeading(eyebrow:"Make it yours",title:"Morning settings.") }.listRowBackground(Color.clear)
                Section("Alarms and movement") {
                    HStack { Label("System alarm access",systemImage:"alarm"); Spacer(); Text(store.alarmAccess ? "Allowed" : "Not enabled").font(.caption).foregroundStyle(Dawn.muted) }
                    Button("Open app permissions") { openURL(URL(string:UIApplication.openSettingsURLString)!) }
                    Toggle("Play music during rituals",isOn:Binding(get:{store.soundEnabled},set:{store.setSound($0)})).tint(Dawn.orange)
                    Text("Music follows the device volume. System alarm sounds are separate. Test an alarm on this device before relying on it.").font(.caption).foregroundStyle(Dawn.muted)
                }
                Section("Wake Me Up Plus") {
                    Button(purchases.hasPlus ? "Your Plus plan" : "Explore Plus") { plus = true }
                    Button("Restore purchases") { Task { await purchases.restore() } }.disabled(purchases.busy)
                    Button("Manage subscriptions") { manage = true }
                    if let message = purchases.message { Text(message).font(.caption).foregroundStyle(Dawn.muted) }
                }
                Section("Your privacy") {
                    Label("No account or advertising",systemImage:"person.crop.circle.badge.checkmark")
                    Text("Alarms, moods, and journal entries stay on this device. Optional camera images and motion readings are processed locally and never recorded or uploaded. Apple handles purchases. Device backups may include local app data.").font(.subheadline).foregroundStyle(Dawn.muted)
                    Link("Privacy policy",destination:URL(string:"https://oanarinaldi.com/wakemeupprivacy.html")!)
                    Button("Clear sunrise journal",role:.destructive) { clear = true }
                }
                Section("A little help") {
                    Link("Support and alarm guide",destination:URL(string:"https://oanarinaldi.com/wakemeupsupport.html")!)
                    Link("Contact Oana",destination:URL(string:"mailto:oanaunciuleanu@gmail.com?subject=Wake%20Me%20Up%20Support")!)
                    Link("Terms of use",destination:URL(string:"https://oanarinaldi.com/wakemeupterms.html")!)
                    Text("Move within your comfort. Camera and motion counts are estimates. This app is a morning habit tool, not a medical or fitness assessment.").font(.caption).foregroundStyle(Dawn.muted)
                }
                Section { VStack(alignment:.leading,spacing:5) { Text("Made for brighter mornings.").font(Dawn.title(20)); Text("Wake Me Up 1.0 · by Oana Rinaldi").font(.caption).foregroundStyle(Dawn.muted) } }.listRowBackground(Color.clear)
            }.scrollContentBackground(.hidden).background(Dawn.cream).foregroundStyle(Dawn.ink).toolbar(.hidden,for:.navigationBar)
                .sheet(isPresented:$plus) { PlusView() }.manageSubscriptionsSheet(isPresented:$manage)
                .confirmationDialog("Clear all sunrise entries on this device?",isPresented:$clear,titleVisibility:.visible) { Button("Clear journal",role:.destructive) { store.clearJournal() } } message: { Text("Your alarms and Apple subscription remain active. This removes the local journal and streak.") }
        }
    }
}

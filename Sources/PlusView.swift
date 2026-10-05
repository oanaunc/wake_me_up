import SwiftUI
import StoreKit

struct PlusView: View {
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String = PurchaseStore.identifiers[1]
    @State private var showManage = false
    var chosen: Product? { purchases.products.first { $0.id == selected } ?? purchases.products.last }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Label("WAKE ME UP PLUS",systemImage:"sparkles").font(.caption.bold()).tracking(2).foregroundStyle(Dawn.orange); Spacer() }
                    HStack(alignment: .center) { Text("More room\nfor your mornings.").font(Dawn.title(36)); Spacer(); Artwork(name:"SunMascot").frame(width: 100,height: 100).clipShape(Circle()) }
                    Text("Make a ritual that feels like you. All the essentials stay free.").font(.body).foregroundStyle(Dawn.muted)
                    VStack(alignment:.leading,spacing: 20) {
                        perk("Up to 20 alarms", "Weekdays, weekends, and every rhythm in between.", "alarm")
                        perk("Your own movement goals", "1–30 reps or sun taps, or 10–180 seconds of a timed challenge.", "figure.dance")
                        perk("Longer practice sessions", "Build confidence with a 60-second dance ritual.", "sun.max")
                    }.dawnCard(Dawn.peach.opacity(0.5))
                    if purchases.hasPlus {
                        Label("Plus is active. Welcome, sunshine.",systemImage: "checkmark.seal.fill").font(.headline)
                        DawnButton(title:"Manage subscription",symbol:"arrow.up.right") { showManage = true }
                    } else {
                        ForEach(purchases.products) { product in
                            Button { selected = product.id } label: {
                                HStack {
                                    Image(systemName:selected == product.id ? "largecircle.fill.circle" : "circle")
                                    VStack(alignment:.leading,spacing:5) { Text(product.id.hasSuffix("yearly") ? "Yearly" : "Monthly").font(.headline); Text("\(product.displayPrice) / \(product.id.hasSuffix("yearly") ? "year" : "month")").font(.subheadline) }
                                    Spacer()
                                    if product.id.hasSuffix("yearly") { Text("A YEAR OF SUNRISES").font(.system(size:9,weight:.bold)).padding(8).background(Dawn.peach,in:Capsule()) }
                                }.foregroundStyle(Dawn.ink).dawnCard(selected == product.id ? Dawn.lavender.opacity(0.6) : .white)
                            }.buttonStyle(.plain)
                        }
                        if let chosen { DawnButton(title:purchases.busy ? "Please wait…" : "Subscribe · \(chosen.displayPrice) / \(chosen.id.hasSuffix("yearly") ? "year" : "month")",symbol:"sparkles") { Task { await purchases.buy(chosen) } }.disabled(purchases.busy) }
                        else { Text("Apple’s subscription prices are unavailable right now. Try again, or keep enjoying the free app.").font(.subheadline).foregroundStyle(Dawn.muted); Button("Reload plans") { Task { await purchases.load() } } }
                        Text("Auto-renewing subscription. Payment is charged to your Apple Account. Renews at the selected price unless canceled at least 24 hours before the period ends. Manage or cancel in Apple Settings → your name → Subscriptions.").font(.caption).foregroundStyle(Dawn.muted)
                    }
                    Button("Restore purchases") { Task { await purchases.restore() } }.disabled(purchases.busy).frame(maxWidth: .infinity).font(.subheadline.bold())
                    if let message = purchases.message { Text(message).font(.subheadline).foregroundStyle(Dawn.muted).multilineTextAlignment(.center).frame(maxWidth:.infinity) }
                    HStack { Link("Privacy",destination:URL(string:"https://oanarinaldi.com/wakemeupprivacy.html")!); Spacer(); Link("Terms",destination:URL(string:"https://oanarinaldi.com/wakemeupterms.html")!); Spacer(); Link("Apple EULA",destination:URL(string:"https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) }.font(.caption)
                    Text("Free: two alarms, all seven challenges, three ringtones, optional camera and motion counting, journal, and unlimited standard practice. No login or ads.").font(.caption).foregroundStyle(Dawn.muted)
                }.padding(24).frame(maxWidth:650).frame(maxWidth:.infinity)
            }.background(Dawn.cream).foregroundStyle(Dawn.ink).toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() } } }.manageSubscriptionsSheet(isPresented:$showManage)
        }.task { if purchases.products.isEmpty { await purchases.load() } }
    }
    func perk(_ title:String,_ detail:String,_ symbol:String)->some View { HStack(alignment:.top,spacing:14) { Image(systemName:symbol).font(.title3).frame(width:28); VStack(alignment:.leading,spacing:4) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(Dawn.muted) } } }
}

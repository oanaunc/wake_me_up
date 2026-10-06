import SwiftUI

enum Dawn {
    static let cream = Color(red: 0.99, green: 0.97, blue: 0.93)
    static let ink = Color(red: 0.22, green: 0.15, blue: 0.25)
    static let muted = Color(red: 0.44, green: 0.37, blue: 0.43)
    static let orange = Color(red: 0.80, green: 0.30, blue: 0.13)
    static let peach = Color(red: 1, green: 0.87, blue: 0.74)
    static let lavender = Color(red: 0.89, green: 0.86, blue: 0.96)
    static let green = Color(red: 0.85, green: 0.91, blue: 0.81)
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func tint(_ mission: Mission) -> Color { switch mission { case .pushups, .squats: peach; case .dance,.sunTaps,.math,.memory,.words: lavender; case .stretch,.march,.breathe,.scanCode,.daylight,.water: green } }
}

struct DawnHeading: View {
    var eyebrow: String
    var title: String
    var subtitle: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow.uppercased()).font(.caption.bold()).tracking(2.5).foregroundStyle(Dawn.orange)
            Text(title).font(Dawn.title(34)).foregroundStyle(Dawn.ink)
            if !subtitle.isEmpty { Text(subtitle).font(.subheadline).foregroundStyle(Dawn.muted).fixedSize(horizontal: false, vertical: true) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct DawnButton: View {
    var title: String
    var symbol = "arrow.right"
    var color = Dawn.ink
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Text(title); Spacer(); Image(systemName: symbol) }.font(.body.weight(.semibold)).padding(18).foregroundStyle(.white).background(color, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain)
    }
}
struct Artwork: View {
    var name: String
    var body: some View { Image(name).resizable().scaledToFit().accessibilityHidden(true) }
}
extension View {
    func dawnCard(_ color: Color = .white) -> some View {
        padding(20).background(color, in: RoundedRectangle(cornerRadius: 26)).overlay(RoundedRectangle(cornerRadius: 26).stroke(Dawn.ink.opacity(0.06)))
    }
}

struct MissionTile: View {
    var mission: Mission
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Image(systemName: mission.symbol).font(.system(size: 29)); Spacer(); Image(systemName: "arrow.up.right").font(.caption.bold()) }
                VStack(alignment: .leading, spacing: 5) { Text(mission.title).font(Dawn.title(20)); Text(mission.subtitle).font(.caption).fixedSize(horizontal: false, vertical: true) }
            }.foregroundStyle(Dawn.ink).frame(maxWidth: .infinity, alignment: .leading).dawnCard(Dawn.tint(mission))
        }.buttonStyle(.plain).accessibilityIdentifier("mission-\(mission.rawValue)")
    }
}

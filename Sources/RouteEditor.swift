import SwiftUI

struct RouteStepEditor:View {
    @Binding var step:RitualStep
    @Environment(WakeStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    var body:some View {
        Form {
            Section {
                Picker("Challenge",selection:$step.mission) {ForEach(Mission.allCases) {mission in Text(mission.title).tag(mission)}}
                    .onChange(of:step.mission) {_,mission in step.target=mission.defaultTarget}
                Text(step.mission.instructions).font(.subheadline).foregroundStyle(Dawn.muted)
            }
            Section("Your goal") {
                if purchases.hasPlus && step.mission.targetRange.count > 1 {
                    Stepper("\(step.target) \(step.mission.unit)",value:$step.target,in:step.mission.targetRange,step:step.mission.isTimer ? 10 : 1)
                } else {Text("\(step.target) \(step.mission.unit)")}
                if step.mission == .math || step.mission == .memory {
                    Picker("Difficulty",selection:$step.difficulty) {Text("Easy").tag(1);Text("Medium").tag(2);Text("Stretch my focus").tag(3)}
                }
                if step.mission == .words {
                    TextField("My morning intention",text:$step.intention,axis:.vertical)
                        .onChange(of:step.intention) {_,value in step.intention=String(value.prefix(160))}
                    Text("Choose a short sentence you would like to type in the morning.").font(.caption)
                }
                if step.mission == .scanCode {
                    Picker("Destination",selection:$step.destinationID) {
                        Text("Guided check-in").tag(Optional<UUID>.none)
                        ForEach(store.destinations) {destination in Text(destination.name).tag(Optional(destination.id))}
                    }
                    NavigationLink("Save a destination code") {DestinationsView()}
                    Text("A matching scan verifies the saved code. Guided check-in uses your own confirmation.").font(.caption).foregroundStyle(Dawn.muted)
                }
            }
        }.scrollContentBackground(.hidden).background(Dawn.cream).navigationTitle(step.mission.title).navigationBarTitleDisplayMode(.inline)
    }
}
struct DestinationsView:View {
    @Environment(WakeStore.self) private var store
    @State private var name="Kitchen"
    @State private var scanning=false
    @State private var code:String?
    var body:some View {
        Form {
            Section {
                Text("Choose a code on a comfortable destination: a cereal box, toothpaste, or a QR label. Only a one-way code fingerprint is saved.").font(.subheadline).foregroundStyle(Dawn.muted)
                TextField("Destination name",text:$name)
                Button(code == nil ? "Scan a barcode or QR code" : "Code scanned · scan another") {scanning=true}
                Button("Save destination") {
                    guard let code else {return}
                    store.addDestination(name:name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "My destination" : name,code:code)
                    self.code=nil
                }.disabled(code == nil).accessibilityIdentifier("save-destination")
            }
            Section("Your destinations") {
                if store.destinations.isEmpty {Text("No destination codes yet. Guided check-in is always available.")}
                ForEach(store.destinations) {destination in Label(destination.name,systemImage:"qrcode")}
                    .onDelete {offsets in store.removeDestinations(Set(offsets.map {store.destinations[$0].id}))}
                Text("Swipe to remove a destination. Routes that used it return to guided check-in.").font(.caption).foregroundStyle(Dawn.muted)
            }
        }.scrollContentBackground(.hidden).background(Dawn.cream).navigationTitle("Destinations").toolbar(.visible,for:.navigationBar)
            .sheet(isPresented:$scanning) {CodeScanner {code in self.code=code}}
    }
}
struct LocalLibraryView:View {
    @Environment(WakeStore.self) private var store
    var body:some View {
        Form {
            Section("Reusable morning routes") {
                if store.presets.isEmpty {Text("Save a route from the alarm editor.")}
                ForEach(store.presets) {preset in VStack(alignment:.leading,spacing:5) {Text(preset.name).font(.headline);Text(preset.steps.map(\.mission.title).joined(separator:" → ")).font(.caption).foregroundStyle(Dawn.muted)}}
                    .onDelete {offsets in store.removePresets(Set(offsets.map {store.presets[$0].id}))}
                Text("Removing a preset keeps routes already copied into alarms.").font(.caption).foregroundStyle(Dawn.muted)
            }
            Section("Imported sounds") {
                if store.importedTones.isEmpty {Text("Import audio in an alarm's sound settings.")}
                ForEach(store.importedTones) {tone in
                    HStack {Label(tone.name,systemImage:"waveform");Spacer();Button("Remove",role:.destructive) {store.removeTone(tone)}}
                }
                Text("Change alarms using a sound before removing it. Audio is stored only on this device.").font(.caption).foregroundStyle(Dawn.muted)
            }
        }.scrollContentBackground(.hidden).background(Dawn.cream).navigationTitle("Saved routes and sounds").navigationBarTitleDisplayMode(.inline).toolbar(.visible,for:.navigationBar)
    }
}

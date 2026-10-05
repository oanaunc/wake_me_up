import SwiftUI

struct AlarmEditor: View {
    @Environment(WakeStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State var alarm: WakeAlarm
    @State private var showPlus = false
    @State private var localError: String?
    @State private var confirmDelete = false
    @State private var previewAudio = MorningAudio()
    var existing: Bool { store.alarms.contains { $0.id == alarm.id } }
    var time: Binding<Date> { Binding(get: { Calendar.current.date(from: DateComponents(hour: alarm.hour, minute: alarm.minute)) ?? .now }, set: { date in alarm.hour = Calendar.current.component(.hour, from: date); alarm.minute = Calendar.current.component(.minute, from: date) }) }
    var body: some View {
        NavigationStack {
            Form {
                Section { DatePicker("Wake-up time", selection: time, displayedComponents: .hourAndMinute).datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity); TextField("Name your morning", text: $alarm.label).accessibilityIdentifier("alarm-label") }
                Section("Repeat") {
                    HStack(spacing: 4) {
                        ForEach(1...7, id: \.self) { day in
                            Button { if alarm.weekdays.contains(day) { alarm.weekdays.removeAll { $0 == day } } else { alarm.weekdays.append(day) } } label: {
                                Text(Calendar.current.veryShortWeekdaySymbols[day-1]).font(.subheadline.bold()).frame(maxWidth: .infinity).frame(height: 44).background(alarm.weekdays.contains(day) ? Dawn.ink : Dawn.cream,in: Circle()).foregroundStyle(alarm.weekdays.contains(day) ? .white : Dawn.ink)
                            }.buttonStyle(.plain).accessibilityLabel(Calendar.current.weekdaySymbols[day-1]).accessibilityValue(alarm.weekdays.contains(day) ? "Selected" : "Not selected")
                        }
                    }
                    Text(alarm.repeatText).font(.caption).foregroundStyle(Dawn.muted)
                }
                Section("Your first move") {
                    ForEach(Mission.allCases) { mission in
                        Button { alarm.mission = mission; alarm.target = mission.defaultTarget } label: {
                            HStack { Image(systemName: mission.symbol).frame(width: 30); VStack(alignment: .leading) { Text(mission.title).font(.headline); Text(mission.subtitle).font(.caption).foregroundStyle(Dawn.muted) }; Spacer(); if alarm.mission == mission { Image(systemName: "checkmark.circle.fill") } }.foregroundStyle(Dawn.ink).padding(.vertical, 6)
                        }.buttonStyle(.plain)
                    }
                    if purchases.hasPlus {
                        Stepper("\(alarm.target) \(alarm.mission.unit)", value: $alarm.target, in: alarm.mission.isCounted ? 1...30 : 10...180, step: alarm.mission.isCounted ? 1 : 10)
                    } else {
                        HStack { Text("\(alarm.target) \(alarm.mission.unit)"); Spacer(); Button("Customize with Plus") { showPlus = true }.font(.caption.bold()) }
                    }
                }
                Section("Sound") {
                    Picker("Alarm ringtone", selection: $alarm.tone) { Text("First Light · joyful marimba").tag("FirstLight"); Text("Soft Start · gentle piano").tag("SoftStart"); Text("Rise & Shine · upbeat funk").tag("RiseAndShine") }
                    Button("Preview selected sound", systemImage: "play.circle") { previewAudio.play(tone: alarm.tone, enabled: true) }
                    Button("Stop preview", systemImage: "stop.circle") { previewAudio.stop() }
                    Text("Your chosen 25-second ringtone plays through the system alarm. Its matching music can play during your challenge.").font(.caption).foregroundStyle(Dawn.muted)
                }
                Section {
                    Toggle("Enable this alarm", isOn: $alarm.enabled).tint(Dawn.orange)
                } footer: { Text("When enabled, Apple will ask for alarm access. The alarm rings through iOS. Open its movement action for your ritual; iOS can always dismiss the system alarm.") }
                if existing { Section { Button("Delete alarm", role: .destructive) { confirmDelete = true } } }
            }.scrollContentBackground(.hidden).background(Dawn.cream).navigationTitle(existing ? "Your morning" : "New morning").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(store.busy ? "Saving…" : "Save") { Task { if alarm.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { alarm.label = "My morning" }; alarm.label = String(alarm.label.prefix(48)); if await store.saveAlarm(alarm, plus: purchases.hasPlus) { dismiss() } else { localError = store.error; store.error = nil } } }.bold().disabled(store.busy) } }
                .sheet(isPresented: $showPlus) { PlusView() }
                .alert("Alarm not saved", isPresented: Binding(get: { localError != nil }, set: { if !$0 { localError = nil } })) { Button("OK") { localError = nil } } message: { Text(localError ?? "") }
                .confirmationDialog("Remove this alarm?", isPresented: $confirmDelete, titleVisibility: .visible) { Button("Delete alarm", role: .destructive) { Task { if await store.delete(alarm) { dismiss() } else { localError = store.error; store.error = nil } } } }
                .onDisappear { previewAudio.stop() }
        }
    }
}

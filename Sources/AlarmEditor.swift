import SwiftUI
import UniformTypeIdentifiers

struct AlarmEditor:View {
    @Environment(WakeStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State var alarm:WakeAlarm
    @State private var showPlus=false
    @State private var confirmDelete=false
    @State private var importing=false
    @State private var localError:String?
    @State private var exceptionDate=Date.now.addingTimeInterval(86400)
    @State private var previewAudio=MorningAudio()
    @State private var presetName="My morning route"
    var existing:Bool {store.alarms.contains {$0.id == alarm.id}}
    var time:Binding<Date> {Binding(get:{Calendar.current.date(from:DateComponents(hour:alarm.hour,minute:alarm.minute)) ?? .now},set:{date in alarm.hour=Calendar.current.component(.hour,from:date);alarm.minute=Calendar.current.component(.minute,from:date)})}
    var dates:[Date] {alarm.occurrences(count:7)}
    var body:some View {
        NavigationStack {
            Form {
                Section {
                    if alarm.scheduleMode == .dated {
                        DatePicker("Date and time",selection:$alarm.datedAt,in:Date.now...,displayedComponents:[.date,.hourAndMinute])
                            .onChange(of:alarm.datedAt) {_,date in alarm.hour=Calendar.current.component(.hour,from:date);alarm.minute=Calendar.current.component(.minute,from:date)}
                    } else {DatePicker("Wake-up time",selection:time,displayedComponents:.hourAndMinute).datePickerStyle(.wheel).labelsHidden().frame(maxWidth:.infinity)}
                    TextField("Name your morning",text:$alarm.label).accessibilityIdentifier("alarm-label")
                }
                Section("Schedule") {
                    Picker("Repeats",selection:$alarm.scheduleMode) {ForEach(WakeSchedule.allCases) {mode in Text(mode.title).tag(mode)}}
                        .onChange(of:alarm.scheduleMode) {_,mode in if mode == .dated {alarm.nextOverride=nil}}
                    if alarm.scheduleMode == .weekly {
                        HStack(spacing:4) {
                            ForEach(1...7,id:\.self) {day in
                                Button {
                                    if alarm.weekdays.contains(day) {alarm.weekdays.removeAll {$0 == day}} else {alarm.weekdays.append(day)}
                                } label: {Text(Calendar.current.veryShortWeekdaySymbols[day-1]).font(.subheadline.bold()).frame(maxWidth:.infinity).frame(height:44).background(alarm.weekdays.contains(day) ? Dawn.ink : Dawn.cream,in:Circle()).foregroundStyle(alarm.weekdays.contains(day) ? .white : Dawn.ink)}
                                    .buttonStyle(.plain).accessibilityLabel(Calendar.current.weekdaySymbols[day-1]).accessibilityValue(alarm.weekdays.contains(day) ? "Selected" : "Not selected")
                            }
                        }
                    } else if alarm.scheduleMode == .rotation {
                        DatePicker("First work day",selection:$alarm.cycleStart,displayedComponents:.date)
                        Stepper("\(alarm.workDays) work days",value:$alarm.workDays,in:1...30)
                        Stepper("\(alarm.restDays) rest days",value:$alarm.restDays,in:1...30)
                        Text("The cycle repeats from your first work day. Rest days have no alarm.").font(.caption).foregroundStyle(Dawn.muted)
                    }
                    Text(alarm.repeatText).font(.caption).foregroundStyle(Dawn.muted)
                }
                routeSection
                Section("Snooze and stay-awake check") {
                    Picker("System snooze",selection:$alarm.snoozeMinutes) {Text("Off · start my route").tag(0);ForEach([3,5,10,15],id:\.self) {Text("\($0) minutes").tag($0)}}
                    Text(alarm.snoozeMinutes > 0 ? "The system Snooze button waits this long. Stop opens your morning route; iOS retains its own dismissal controls." : "Start moving opens your route. iOS retains its own Stop control.").font(.caption).foregroundStyle(Dawn.muted)
                    Picker("Check I'm still awake",selection:$alarm.wakeCheckMinutes) {Text("Off").tag(0);ForEach([3,5,10,15],id:\.self) {Text("\($0) minutes after completing my route").tag($0)}}
                    Text("An optional second system alarm follows a completed route. Confirm three sun taps, or cancel it anytime.").font(.caption).foregroundStyle(Dawn.muted)
                }
                Section("Sound") {
                    Picker("Alarm ringtone",selection:$alarm.tone) {
                        ForEach(ToneLibrary.builtIn,id:\.self) {Text(ToneLibrary.name($0)).tag($0)}
                        Text(ToneLibrary.name("Surprise")).tag("Surprise")
                        ForEach(store.importedTones) {tone in Text(tone.name).tag(tone.id)}
                    }
                    Toggle("Gentle sound ramp",isOn:$alarm.gentleSound).tint(Dawn.orange)
                    Text("Bundled tones can rise gently over 15 seconds. iOS controls alarm volume. Imported tones play as provided.").font(.caption).foregroundStyle(Dawn.muted)
                    Button("Preview selected sound",systemImage:"play.circle") {previewAudio.play(tone:alarm.tone,enabled:true,volume:store.ritualVolume,gentle:alarm.gentleSound)}
                    Button("Stop preview",systemImage:"stop.circle") {previewAudio.stop()}
                    if let error=previewAudio.error {Text(error).font(.caption).foregroundStyle(Dawn.orange)}
                    Button("Import my own audio",systemImage:"square.and.arrow.down") {importing=true}
                    Text("Import a playable, non-DRM audio file you have permission to use. Its first 25 seconds stay on this device.").font(.caption).foregroundStyle(Dawn.muted)
                }
                if !alarm.isOneShot {
                    Section("Days off and exceptions") {
                        Toggle("Change just the next wake-up time",isOn:Binding(get:{alarm.nextOverride != nil},set:{enabled in alarm.nextOverride=enabled ? alarm.nextFire(after:.now) : nil})).tint(Dawn.orange)
                        if alarm.nextOverride != nil {
                            DatePicker("Next wake-up only",selection:Binding(get:{alarm.nextOverride ?? .now},set:{alarm.nextOverride=$0}),in:Date.now...,displayedComponents:.hourAndMinute)
                            Text("This changes the next scheduled day's time. Later days keep your usual time.").font(.caption).foregroundStyle(Dawn.muted)
                        }
                        DatePicker("Skip this date",selection:$exceptionDate,in:Date.now...,displayedComponents:.date)
                        Button("Add day off") {if !alarm.skippedDates.contains(where:{Calendar.current.isDate($0,inSameDayAs:exceptionDate)}) {alarm.skippedDates.append(exceptionDate)}}
                        ForEach(alarm.skippedDates.sorted(),id:\.self) {date in
                            HStack {Text(date.formatted(date:.abbreviated,time:.omitted));Spacer();Button("Remove") {alarm.skippedDates.removeAll {$0 == date}}.font(.caption)}
                        }
                        if let paused=alarm.pausedUntil {
                            Text("Paused until \(paused.formatted(date:.abbreviated,time:.shortened))")
                            Button("End pause") {alarm.pausedUntil=nil}
                        }
                    }
                }
                Section("Next wake-ups") {
                    if dates.isEmpty {Text("Choose a future date.")}
                    ForEach(dates,id:\.self) {date in
                        HStack {Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()));Spacer();Text(date.formatted(date:.omitted,time:.shortened)).bold()}
                    }
                    if alarm.usesCalendarPlan {
                        Text("Your next 14 wake-up dates are saved with the system. Open Wake Me Up to refill this calendar plan. Check its scheduled-through date on Morning; future dates beyond it are not scheduled yet.").font(.caption).foregroundStyle(Dawn.muted)
                    } else if !alarm.isOneShot {Text("Weekly repeats continue until you turn this alarm off.").font(.caption).foregroundStyle(Dawn.muted)}
                }
                Section {Toggle("Enable this alarm",isOn:$alarm.enabled).tint(Dawn.orange)}
                if existing {Section {Button("Delete alarm",role:.destructive) {confirmDelete=true}}}
            }.scrollContentBackground(.hidden).background(Dawn.cream).navigationTitle(existing ? "Your morning" : "New morning").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) {Button("Cancel") {dismiss()}}
                    ToolbarItem(placement:.confirmationAction) {Button(store.busy ? "Saving…" : "Save") {
                        Task {
                            if alarm.label.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {alarm.label="My morning"}
                            alarm.label=String(alarm.label.prefix(48))
                            if let first=alarm.route.first {alarm.mission=first.mission;alarm.target=first.target}
                            if await store.saveAlarm(alarm,plus:purchases.hasPlus) {dismiss()} else {localError=store.error;store.error=nil}
                        }
                    }.bold().disabled(store.busy)}
                }
                .sheet(isPresented:$showPlus) {PlusView()}
                .fileImporter(isPresented:$importing,allowedContentTypes:[.audio]) {result in
                    Task {do {let url=try result.get();let tone=try await ToneLibrary.importAudio(url);store.addTone(tone);alarm.tone=tone.id}
                        catch {localError=error.localizedDescription}}
                }
                .alert("Alarm not saved",isPresented:Binding(get:{localError != nil},set:{if !$0 {localError=nil}})) {Button("OK") {localError=nil}} message:{Text(localError ?? "")}
                .confirmationDialog("Remove this alarm?",isPresented:$confirmDelete,titleVisibility:.visible) {Button("Delete alarm",role:.destructive) {Task {if await store.delete(alarm) {dismiss()} else {localError=store.error;store.error=nil}}}}
                .onDisappear {previewAudio.stop()}
        }
    }
    var routeSection:some View {
        Section("Your morning route") {
            if alarm.route.isEmpty {
                Picker("First move",selection:$alarm.mission) {ForEach(Mission.allCases) {mission in Text(mission.title).tag(mission)}}
                    .onChange(of:alarm.mission) {_,mission in alarm.target=mission.defaultTarget}
                Text(alarm.mission.subtitle).font(.subheadline).foregroundStyle(Dawn.muted)
                if purchases.hasPlus && alarm.mission.targetRange.count > 1 {Stepper("\(alarm.target) \(alarm.mission.unit)",value:$alarm.target,in:alarm.mission.targetRange,step:alarm.mission.isTimer ? 10 : 1)}
                else {Text("\(alarm.target) \(alarm.mission.unit)")}
                Button("Build a multi-step route",systemImage:"point.topleft.down.to.point.bottomright.curvepath") {alarm.route=[RitualStep(mission:alarm.mission,target:alarm.target)]}.accessibilityIdentifier("build-route")
            } else {
                ForEach(Array(alarm.route.enumerated()),id:\.element.id) {index,step in
                    HStack {
                        NavigationLink {RouteStepEditor(step:$alarm.route[index])} label: {
                            VStack(alignment:.leading,spacing:5) {Label("Step \(index+1) · \(step.mission.title)",systemImage:step.mission.symbol);Text("\(step.target) \(step.mission.unit)").font(.caption).foregroundStyle(Dawn.muted)}
                        }
                        Menu {
                            if index > 0 {Button("Move earlier") {alarm.route.swapAt(index,index-1)}}
                            if index < alarm.route.count-1 {Button("Move later") {alarm.route.swapAt(index,index+1)}}
                            if alarm.route.count > 1 {Button("Remove step",role:.destructive) {alarm.route.remove(at:index)}}
                        } label:{Image(systemName:"ellipsis.circle").frame(width:44,height:44)}
                    }
                }
                if alarm.route.count < 5 {Button("Add a step",systemImage:"plus") {alarm.route.append(RitualStep(mission:.daylight))}.accessibilityIdentifier("add-route-step")}
                Text("Up to five short steps. Every standard challenge and multi-step route is free.").font(.caption).foregroundStyle(Dawn.muted)
                TextField("Save route as",text:$presetName)
                Button("Save as a reusable route") {store.savePreset(name:presetName,steps:alarm.route)}
                Button("Use one step instead") {if let first=alarm.route.first {alarm.mission=first.mission;alarm.target=first.target};alarm.route=[]}
            }
            Menu("Choose a ready-made route") {
                Button("Gentle start · breathe, stretch, light") {alarm.route=[RitualStep(mission:.breathe),RitualStep(mission:.stretch),RitualStep(mission:.daylight)]}
                Button("Focus and feet · maths, march, destination") {alarm.route=[RitualStep(mission:.math),RitualStep(mission:.march),RitualStep(mission:.scanCode)]}
                Button("Tiny joy · sun taps, dance, drink") {alarm.route=[RitualStep(mission:.sunTaps),RitualStep(mission:.dance),RitualStep(mission:.water)]}
                ForEach(store.presets) {preset in Button(preset.name) {alarm.route=preset.steps}}
            }
        }
    }
}

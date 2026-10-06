import SwiftUI

struct JournalView: View {
    @Environment(WakeStore.self) private var store
    var days: [Date] { (0..<28).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: .now)) } }
    @State private var sharing=false
    @State private var exportURL:URL?
    var uniqueDays: Int { Set(store.sunrises.map { Calendar.current.startOfDay(for: $0.date) }).count }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DawnHeading(eyebrow: "Your sunrise journal",title: "Look at you, showing up.",subtitle: "A little collection of mornings you made your own.")
                    HStack(spacing:16) {if !store.hideStreak {metric("\(store.streak)","day streak","flame")};metric("\(uniqueDays)","bright mornings","sun.max")}
                    insights
                    Button("Export my sunrise journal",systemImage:"square.and.arrow.up") {exportURL=store.exportJournal();sharing=exportURL != nil}
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("The last 28 days").font(Dawn.title(22)); Spacer(); Image(systemName: "sun.horizon") }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 14) {
                            ForEach(days, id: \.self) { day in
                                let done = store.sunrises.contains { Calendar.current.isDate($0.date,inSameDayAs: day) }
                                VStack(spacing: 5) {
                                    Image(systemName: done ? "sun.max.fill" : "circle.dotted").font(.system(size: 23)).foregroundStyle(done ? Dawn.orange : Dawn.muted.opacity(0.45))
                                    Text(day.formatted(.dateTime.day())).font(.caption2).foregroundStyle(Dawn.muted)
                                }.frame(maxWidth: .infinity).padding(.vertical,5).background(Calendar.current.isDateInToday(day) ? Dawn.peach.opacity(0.5) : .clear,in:RoundedRectangle(cornerRadius: 12)).accessibilityElement(children: .ignore).accessibilityLabel("\(day.formatted(date: .complete,time: .omitted)), \(done ? "sunrise completed" : "no completed ritual")")
                            }
                        }
                        Text("A streak counts consecutive days with a completed alarm ritual. Multiple alarms on one day count as one bright morning.").font(.caption).foregroundStyle(Dawn.muted)
                    }.dawnCard()
                    Text("Morning moments").font(Dawn.title(22))
                    if store.sunrises.isEmpty {
                        VStack(spacing: 16) { Image(systemName: "sun.horizon.fill").font(.system(size: 48)).foregroundStyle(Dawn.orange); Text("Your first sunrise is waiting.").font(Dawn.title(24)); Text("Complete a movement after an alarm, then save your sunrise. No pressure to be perfect.").font(.subheadline).foregroundStyle(Dawn.muted).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).dawnCard(Dawn.peach.opacity(0.55))
                    }
                    ForEach(store.sunrises.sorted { $0.date > $1.date }) { record in
                        HStack(spacing: 16) {
                            Image(systemName: record.mission.symbol).font(.title2).frame(width: 50,height: 50).background(Dawn.tint(record.mission),in:Circle())
                            VStack(alignment: .leading, spacing: 5) { Text(record.date.formatted(.dateTime.month(.wide).day())).font(.headline); Text(record.steps?.map {"\($0.mission.title) · \($0.amount) \($0.mission.unit)"}.joined(separator:" → ") ?? "\(record.amount) \(record.mission.unit) · \(record.mission.title)").font(.caption).foregroundStyle(Dawn.muted) }
                            Spacer(); if record.wakeCheckConfirmedAt != nil {Image(systemName:"checkmark.sun.fill").foregroundStyle(Dawn.orange)}
                            if let mood = record.mood { Text(mood).font(.caption.bold()).foregroundStyle(Dawn.orange) }
                        }.dawnCard()
                    }
                }.padding(24).frame(maxWidth: 900).frame(maxWidth: .infinity)
            }.sheet(isPresented:$sharing) {if let exportURL {JournalShareSheet(url:exportURL)}}
            .background(Dawn.cream).toolbar(.hidden,for: .navigationBar).foregroundStyle(Dawn.ink)
        }
    }
    var insights:some View {
        let recent=store.sunrises.filter {$0.date >= Calendar.current.date(byAdding:.day,value:-7,to:.now)!}
        let durations=recent.compactMap(\.durationSeconds)
        let confirmed=recent.filter {$0.wakeCheckConfirmedAt != nil}.count
        return VStack(alignment:.leading,spacing:14) {
            Text("Your last seven days").font(Dawn.title(22))
            HStack {
                VStack(alignment:.leading) {Text("\(Set(recent.map {Calendar.current.startOfDay(for:$0.date)}).count)").font(Dawn.title(30));Text("bright mornings").font(.caption)}
                Spacer()
                VStack(alignment:.leading) {Text("\(confirmed)").font(Dawn.title(30));Text("wake-up checks confirmed").font(.caption)}
            }
            if !durations.isEmpty {Text("Average route time: \(Int(durations.reduce(0,+)/Double(durations.count))) seconds, including pauses.").font(.caption).foregroundStyle(Dawn.muted)}
            Text("Only completed alarm routes count here. Practice stays separate. Your history is a record of returns, not a score you have to protect.").font(.caption).foregroundStyle(Dawn.muted)
        }.dawnCard(Dawn.green.opacity(0.6))
    }
    func metric(_ value: String,_ label: String,_ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 9) { Image(systemName: symbol).foregroundStyle(Dawn.orange); Text(value).font(Dawn.title(42)); Text(label).font(.subheadline).foregroundStyle(Dawn.muted) }.frame(maxWidth:.infinity,alignment:.leading).dawnCard()
    }
}

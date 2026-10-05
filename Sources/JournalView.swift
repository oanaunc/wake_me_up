import SwiftUI

struct JournalView: View {
    @Environment(WakeStore.self) private var store
    var days: [Date] { (0..<28).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: .now)) } }
    var uniqueDays: Int { Set(store.sunrises.map { Calendar.current.startOfDay(for: $0.date) }).count }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DawnHeading(eyebrow: "Your sunrise journal",title: "Look at you, showing up.",subtitle: "A little collection of mornings you made your own.")
                    HStack(spacing: 16) { metric("\(store.streak)","day streak", "flame"); metric("\(uniqueDays)","bright mornings", "sun.max") }
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
                            VStack(alignment: .leading, spacing: 5) { Text(record.date.formatted(.dateTime.month(.wide).day())).font(.headline); Text("\(record.amount) \(record.mission.unit) · \(record.mission.title)").font(.caption).foregroundStyle(Dawn.muted) }
                            Spacer(); if let mood = record.mood { Text(mood).font(.caption.bold()).foregroundStyle(Dawn.orange) }
                        }.dawnCard()
                    }
                }.padding(24).frame(maxWidth: 900).frame(maxWidth: .infinity)
            }.background(Dawn.cream).toolbar(.hidden,for: .navigationBar).foregroundStyle(Dawn.ink)
        }
    }
    func metric(_ value: String,_ label: String,_ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 9) { Image(systemName: symbol).foregroundStyle(Dawn.orange); Text(value).font(Dawn.title(42)); Text(label).font(.subheadline).foregroundStyle(Dawn.muted) }.frame(maxWidth:.infinity,alignment:.leading).dawnCard()
    }
}

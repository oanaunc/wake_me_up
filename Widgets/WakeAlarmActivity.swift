import SwiftUI
import WidgetKit
import AlarmKit

@main struct WakeAlarmActivity:Widget {
    var body:some WidgetConfiguration {
        ActivityConfiguration(for:AlarmAttributes<WakeMetadata>.self) {context in
            HStack {
                Image(systemName:"sun.max.fill").foregroundStyle(.orange)
                VStack(alignment:.leading,spacing:5) {
                    Text("Wake Me Up").font(.headline)
                    if case .countdown(let countdown)=context.state.mode {
                        Text("A few more minutes").font(.caption)
                        Text(timerInterval:countdown.startDate...countdown.fireDate,countsDown:true).monospacedDigit()
                    } else {Text("Your morning is ready.").font(.caption)}
                }
                Spacer()
            }.padding(16).activityBackgroundTint(Color(red:0.99,green:0.97,blue:0.93)).activitySystemActionForegroundColor(Color(red:0.22,green:0.15,blue:0.25))
        } dynamicIsland: {context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {Image(systemName:"sun.max.fill").foregroundStyle(.orange)}
                DynamicIslandExpandedRegion(.trailing) {timer(context.state)}
                DynamicIslandExpandedRegion(.bottom) {Text("Wake Me Up · your morning, your choice").font(.caption)}
            } compactLeading:{Image(systemName:"sun.max.fill").foregroundStyle(.orange)} compactTrailing:{timer(context.state)} minimal:{Image(systemName:"sun.max.fill").foregroundStyle(.orange)}
        }
    }
    @ViewBuilder func timer(_ state:AlarmPresentationState)->some View {
        if case .countdown(let countdown)=state.mode {Text(timerInterval:countdown.startDate...countdown.fireDate,countsDown:true).monospacedDigit().frame(maxWidth:80)}
        else {Image(systemName:"alarm")}
    }
}

import SwiftUI

struct MathsMission:View {
    var target:Int
    var difficulty:Int
    var completed:()->Void
    @State private var a=0
    @State private var b=0
    @State private var operation=0
    @State private var answer=""
    @State private var feedback=""
    @FocusState private var editing:Bool
    var prompt:String {"\(a) \(operation == 1 ? "×" : operation == 2 ? "−" : "+") \(b)"}
    var body:some View {
        VStack(spacing:14) {
            Text(prompt).font(Dawn.title(48)).accessibilityIdentifier("math-prompt")
            TextField("Your answer",text:$answer).keyboardType(.asciiCapableNumberPad).autocorrectionDisabled().focused($editing).textFieldStyle(.roundedBorder).font(.title2).accessibilityIdentifier("math-answer")
            DawnButton(title:"Check my answer",symbol:"checkmark") {
                if Int(answer.trimmingCharacters(in:.whitespacesAndNewlines)) == FocusChallenge.answer(a,b,operation:operation) {completed();newQuestion()}
                else {feedback="Try again. There is no rush."}
            }.accessibilityIdentifier("math-submit")
            if !feedback.isEmpty {Text(feedback).font(.caption).foregroundStyle(Dawn.muted)}
        }.onAppear {newQuestion()}
            .toolbar {ToolbarItemGroup(placement:.keyboard) {Spacer();Button("Done") {editing=false}.accessibilityIdentifier("math-keyboard-done")}}
    }
    func newQuestion() {
        a=Int.random(in:difficulty >= 3 ? 2...12 : difficulty == 2 ? 10...30 : 1...9)
        b=Int.random(in:difficulty >= 3 ? 2...12 : difficulty == 2 ? 1...20 : 1...9)
        operation=difficulty >= 3 ? 1 : difficulty == 2 ? Int.random(in:0...1)*2 : 0
        if operation == 2 && b > a {swap(&a,&b)}
        answer="";feedback="";editing=false
    }
}
struct MemoryMission:View {
    var difficulty:Int
    var completed:()->Void
    @State private var sequence:[Int]=[]
    @State private var cursor=0
    @State private var showing=true
    @State private var feedback=""
    @State private var generation=UUID()
    var body:some View {
        VStack(spacing:14) {
            Text(showing ? "Remember the numbered trail." : "Tap the same spots, in order.").font(.headline)
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12) {
                ForEach(0..<4) {spot in
                    Button {
                        guard !showing else {return}
                        if sequence[cursor] == spot {
                            cursor += 1
                            if cursor == sequence.count {completed();newRound()}
                        } else {cursor=0;feedback="Start this trail again, or replay it."}
                    } label: {
                        VStack(spacing:6) {
                            Image(systemName:showing && sequence.contains(spot) ? "sun.max.fill" : "circle.dotted").font(.title)
                            Text(showing ? sequence.enumerated().filter {$0.element == spot}.map {String($0.offset+1)}.joined(separator:", ") : "\(spot+1)").font(.headline)
                        }.frame(maxWidth:.infinity).frame(height:90).background(Dawn.peach,in:RoundedRectangle(cornerRadius:20)).foregroundStyle(Dawn.ink)
                    }.buttonStyle(.plain).accessibilityLabel(showing ? "Spot \(spot+1), \(sequence.enumerated().filter {$0.element == spot}.map {String($0.offset+1)}.joined(separator:", "))" : "Spot \(spot+1)").accessibilityIdentifier("memory-spot-\(spot)")
                }
            }
            if showing {Button("I'm ready to repeat it") {showing=false;cursor=0}.accessibilityIdentifier("memory-ready")}
            else {Button("Replay the trail") {showing=true;cursor=0;feedback=""}.accessibilityIdentifier("memory-replay")}
            if !feedback.isEmpty {Text(feedback).font(.caption).foregroundStyle(Dawn.muted)}
        }.onAppear {newRound()}
    }
    func newRound() {sequence=Array((0..<4).shuffled().prefix(min(4,max(2,difficulty+1))));cursor=0;showing=true;feedback=""}
}
struct WordsMission:View {
    var intention:String
    var completed:()->Void
    @State private var answer=""
    @State private var feedback=""
    @FocusState private var editing:Bool
    var body:some View {
        VStack(spacing:14) {
            Text(intention).font(Dawn.title(24)).multilineTextAlignment(.center)
            TextField("Type your intention",text:$answer,axis:.vertical).focused($editing).textFieldStyle(.roundedBorder).accessibilityIdentifier("intention-answer")
            DawnButton(title:"Keep this little promise",symbol:"checkmark") {
                if !FocusChallenge.normalized(intention).isEmpty && FocusChallenge.normalized(answer) == FocusChallenge.normalized(intention) {completed()}
                else {feedback="Copy the intention above. Case and punctuation can differ."}
            }.accessibilityIdentifier("intention-submit")
            if !feedback.isEmpty {Text(feedback).font(.caption).foregroundStyle(Dawn.muted)}
        }.toolbar {ToolbarItemGroup(placement:.keyboard) {Spacer();Button("Done") {editing=false}.accessibilityIdentifier("words-keyboard-done")}}
    }
}
struct DestinationMission:View {
    var destination:Destination?
    var completed:(_ mode:String)->Void
    @State private var scanning=false
    @State private var feedback=""
    var body:some View {
        VStack(spacing:14) {
            Text(destination?.name ?? "Your chosen destination").font(Dawn.title(24))
            if let destination {
                DawnButton(title:"Scan my destination",symbol:"qrcode.viewfinder") {scanning=true}.accessibilityIdentifier("scan-destination")
                Text("Match the code you saved at this destination.").font(.caption).foregroundStyle(Dawn.muted)
                if !feedback.isEmpty {Text(feedback).font(.caption).foregroundStyle(Dawn.orange)}
                Button("Use guided destination check-in") {completed("manual destination check-in")}.font(.subheadline.bold())
            } else {
                Text("No code is attached to this practice. Go to a comfortable destination and confirm it yourself.").font(.subheadline).foregroundStyle(Dawn.muted)
                DawnButton(title:"I'm at my destination",symbol:"checkmark") {completed("manual destination check-in")}
            }
        }.sheet(isPresented:$scanning) {
            CodeScanner {code in
                if Destination.hash(code) == destination?.digest {completed("matching barcode")}
                else {feedback="That code does not match. Try your saved destination code."}
            }
        }
    }
}
struct AwakeCheckView:View {
    var check:PendingWakeCheck
    @Environment(WakeStore.self) private var store
    @State private var taps=0
    var body:some View {
        VStack(spacing:24) {
            DawnHeading(eyebrow:"Your wake-up check",title:"Still with the sunshine?",subtitle:"Tap three suns to confirm you're awake. This is your choice, not an exercise requirement.")
            Artwork(name:"SunMascot").frame(height:240)
            Text("\(taps) / 3").font(Dawn.title(48))
            DawnButton(title:taps == 3 ? "Yes, I'm awake" : "Tap a little sunshine",symbol:"sun.max.fill") {
                if taps < 3 {taps += 1} else {_=store.confirmAwake(check)}
            }.accessibilityIdentifier("awake-confirm")
            Button("Cancel this check") {store.cancelCheck(check)}.font(.subheadline.bold())
            Spacer()
        }.padding(24).frame(maxWidth:650).frame(maxWidth:.infinity).background(Dawn.cream).foregroundStyle(Dawn.ink)
    }
}

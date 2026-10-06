import AVFoundation
import Observation

@MainActor @Observable final class MorningAudio {
    private var player:AVAudioPlayer?
    private(set) var error:String?
    func play(tone:String,enabled:Bool,volume:Double = 0.55,gentle:Bool = false) {
        stop()
        error=nil
        guard enabled,let url=ToneLibrary.previewURL(tone) else {return}
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,mode:.default,options:[.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player=try AVAudioPlayer(contentsOf:url); player?.numberOfLoops = -1
            player?.volume=gentle ? 0.05 : Float(volume)
            guard player?.play() == true else {throw WakeError.message("The selected sound could not play.")}
            if gentle {player?.setVolume(Float(volume),fadeDuration:8)}
        } catch {player=nil;self.error="Music is unavailable. You can continue your route or choose another sound.";try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)}
    }
    func stop() {player?.stop();player=nil;try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)}
}

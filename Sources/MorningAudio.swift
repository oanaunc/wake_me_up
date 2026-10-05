import AVFoundation

@MainActor final class MorningAudio {
    private var player: AVAudioPlayer?
    func play(tone: String, enabled: Bool) {
        stop()
        guard enabled, let url = Bundle.main.url(forResource: tone, withExtension: "m4a") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url); player?.numberOfLoops = -1; player?.volume = 0.55; player?.play()
        } catch { player = nil }
    }
    func stop() { player?.stop(); player = nil; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
}

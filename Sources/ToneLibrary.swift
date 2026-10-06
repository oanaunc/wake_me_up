import Foundation
import AVFoundation

struct ImportedTone:Codable,Identifiable,Equatable {
    var id:String
    var name:String
}
@MainActor enum ToneLibrary {
    static let builtIn = ["FirstLight","SoftStart","RiseAndShine","BrightMarimba","QuietKeys","MorningGroove"]
    static func name(_ id:String,custom:[ImportedTone] = [])->String {
        switch id {
        case "FirstLight": return "First Light · joyful marimba"
        case "SoftStart": return "Soft Start · gentle piano"
        case "RiseAndShine": return "Rise & Shine · upbeat funk"
        case "BrightMarimba": return "Bright Marimba · lively refrain"
        case "QuietKeys": return "Quiet Keys · soft piano"
        case "MorningGroove": return "Morning Groove · funk refrain"
        case "Surprise": return "Different sound each morning"
        default: return custom.first {$0.id == id}?.name ?? "Imported sound"
        }
    }
    static var directory:URL {URL.libraryDirectory.appending(path:"Sounds",directoryHint:.isDirectory)}
    static func alarmFilename(_ id:String,gentle:Bool)->String? {
        let name = id + (gentle ? "AlarmGentle" : "Alarm") + ".caf"
        if FileManager.default.fileExists(atPath:directory.appending(path:name).path) || Bundle.main.url(forResource:name,withExtension:nil) != nil {return name}
        let normal=id+"Alarm.caf"
        return FileManager.default.fileExists(atPath:directory.appending(path:normal).path) || Bundle.main.url(forResource:normal,withExtension:nil) != nil ? normal : nil
    }
    static func previewURL(_ id:String)->URL? {
        if id.hasPrefix("custom_") { return directory.appending(path:id+"Alarm.caf") }
        return Bundle.main.url(forResource:id == "Surprise" ? "FirstLight" : id,withExtension:"m4a")
    }
    static func importAudio(_ url:URL) async throws -> ImportedTone {
        let scope=url.startAccessingSecurityScopedResource(); defer {if scope {url.stopAccessingSecurityScopedResource()}}
        let values=try url.resourceValues(forKeys:[.fileSizeKey])
        guard (values.fileSize ?? 0) <= 50_000_000 else {throw WakeError.message("Choose an audio file smaller than 50 MB.")}
        let input=try AVAudioFile(forReading:url)
        guard input.processingFormat.channelCount <= 2, input.processingFormat.sampleRate <= 96000 else {throw WakeError.message("Choose mono or stereo audio at 96 kHz or below.")}
        guard input.length > 0, input.fileFormat.sampleRate > 0 else {throw WakeError.message("Choose a playable audio file.")}
        let frames=min(input.length,AVAudioFramePosition(input.processingFormat.sampleRate*25))
        guard let buffer=AVAudioPCMBuffer(pcmFormat:input.processingFormat,frameCapacity:AVAudioFrameCount(frames)) else {throw WakeError.message("This audio format could not be imported.")}
        try input.read(into:buffer,frameCount:AVAudioFrameCount(frames))
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let id="custom_"+UUID().uuidString
        let outputURL=directory.appending(path:id+"Alarm.caf")
        // PCM CAF avoids compressed-alarm decoding differences between devices.
        let settings:[String:Any]=[AVFormatIDKey:kAudioFormatLinearPCM,AVSampleRateKey:input.processingFormat.sampleRate,AVNumberOfChannelsKey:input.processingFormat.channelCount,AVLinearPCMBitDepthKey:16,AVLinearPCMIsFloatKey:false,AVLinearPCMIsBigEndianKey:false]
        let output=try AVAudioFile(forWriting:outputURL,settings:settings,commonFormat:input.processingFormat.commonFormat,interleaved:input.processingFormat.isInterleaved)
        try output.write(from:buffer)
        return ImportedTone(id:id,name:String(url.deletingPathExtension().lastPathComponent.prefix(48)))
    }
}

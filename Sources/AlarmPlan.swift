import Foundation
import CryptoKit

enum AlarmPlan {
    static let count = 14
    static func instanceID(_ id:UUID,_ index:Int)->UUID {
        if index == 0 {return id}
        let bytes=Array(SHA256.hash(data:Data("\(id.uuidString):occurrence:\(index)".utf8)))
        return UUID(uuid:(bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }
    static func owner(of id:UUID,alarms:[WakeAlarm])->WakeAlarm? {
        alarms.first {alarm in (0..<count).contains {instanceID(alarm.id,$0) == id}}
    }
    static func dates(_ alarm:WakeAlarm,after date:Date = .now)->[Date] {alarm.occurrences(after:date,count:count)}
}
enum FocusChallenge {
    static func answer(_ a:Int,_ b:Int,operation:Int)->Int { operation == 1 ? a*b : operation == 2 ? a-b : a+b }
    static func normalized(_ text:String)->String {
        text.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:.current).unicodeScalars.filter {CharacterSet.alphanumerics.contains($0)}.map(String.init).joined()
    }
}

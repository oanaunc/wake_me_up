import UserNotifications

@MainActor enum MorningNotifications {
    static func bedtime(enabled:Bool,hour:Int,minute:Int) async throws {
        let center=UNUserNotificationCenter.current()
        if !enabled {center.removePendingNotificationRequests(withIdentifiers:["wake.bedtime"]);return}
        guard try await center.requestAuthorization(options:[.alert,.sound]) else {throw WakeError.message("Allow notifications in Settings to receive bedtime reminders. Your alarms use their separate alarm permission.")}
        let content=UNMutableNotificationContent();content.title="Make room for tomorrow";content.body="Choose your morning route, then give yourself time to rest.";content.sound = .default
        let trigger=UNCalendarNotificationTrigger(dateMatching:DateComponents(hour:hour,minute:minute),repeats:true)
        try await center.add(UNNotificationRequest(identifier:"wake.bedtime",content:content,trigger:trigger))
    }
}

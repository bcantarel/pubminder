//
//  NotificationManager.swift
//  PubMinder
//

import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {}

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshStatus()
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Schedule (or reschedule) the daily digest. Call whenever the time changes.
    func scheduleDailyDigest(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dailyDigest"])

        var components = DateComponents()
        components.hour   = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Your daily research digest"
        content.body  = "New papers are ready in PubMinder."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "dailyDigest",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelDailyDigest() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["dailyDigest"])
    }
}

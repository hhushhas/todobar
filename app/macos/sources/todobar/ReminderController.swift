import AppKit
import Foundation
import UserNotifications

@MainActor
final class ReminderController: NSObject, UNUserNotificationCenterDelegate {
    private let effects: EffectsController
    private weak var appState: AppState?
    private var timer: Timer?

    init(effects: EffectsController, requestNotificationAuthorization: Bool = true) {
        self.effects = effects
        super.init()
        guard requestNotificationAuthorization else { return }
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func bind(appState: AppState) {
        self.appState = appState
    }

    func schedule(for tasks: [TodoTask]) {
        timer?.invalidate()
        let next = tasks
            .filter { !$0.completed && $0.reminderFiredAt == nil }
            .compactMap(\.reminderAt)
            .filter { $0 > Date() }
            .min()

        guard let next else { return }
        timer = Timer.scheduledTimer(withTimeInterval: max(1, next.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fireDueReminders()
            }
        }
    }

    func fireDueReminders() {
        guard let appState else { return }
        let dueTasks = appState.tasks.filter(\.reminderIsDue)
        guard !dueTasks.isEmpty else {
            schedule(for: appState.tasks)
            return
        }

        if NSApp.isActive {
            let title = dueTasks.count == 1 ? dueTasks[0].title : "\(dueTasks.count) tasks are ready"
            effects.showReminder(title: title)
        }
        for task in dueTasks {
            notify(task)
            appState.markReminderFired(task)
        }
        schedule(for: appState.tasks)
    }

    private func notify(_ task: TodoTask) {
        let content = UNMutableNotificationContent()
        content.title = "TodoBar reminder"
        content.body = task.title
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: task.id,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.list, .sound]
    }
}

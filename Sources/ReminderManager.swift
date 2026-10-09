import Foundation
import UserNotifications

/// 一条提醒
struct Reminder: Codable, Equatable {
    var id: String
    var title: String
    var fireDate: Date
    var createdAt: Date

    init(title: String, minutes: Double) {
        self.id = UUID().uuidString
        self.title = title
        self.createdAt = Date()
        self.fireDate = Date().addingTimeInterval(minutes * 60)
    }

    init(title: String, at date: Date) {
        self.id = UUID().uuidString
        self.title = title
        self.createdAt = Date()
        self.fireDate = date
    }
}

/// 提醒的集中管理：列表、持久化、通知调度
final class ReminderManager {

    private(set) var reminders: [Reminder] = []

    /// 是否调度系统通知（默认开启；测试环境或特殊场景可关闭）
    var notificationEnabled = true

    /// UI 刷新回调（列表或下一个提醒发生变化时触发）
    var onChange: (() -> Void)?

    /// 到点回调（参数为提醒标题）。无论 StatusBarView 还是到期 ticker 谁先调用
    /// pruneExpired()，每一条提醒都只会触发一次（firedDueIDs 防重）。
    var onDue: ((String) -> Void)?

    /// 已触发过烟火提醒的 id（防止同一提醒被重复触发）
    private var firedDueIDs = Set<String>()

    private var storageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("DragReminder", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("reminders.json")
    }

    init() {
        load()
        // 启动时清理已过期的提醒（通知已由系统负责，本地不再保留）
        pruneExpired()
    }

    // MARK: - 增删查

    func add(title: String, minutes: Double) {
        let r = Reminder(title: title, minutes: minutes)
        reminders.append(r)
        scheduleNotification(for: r)
        save()
        onChange?()
    }

    func add(title: String, at date: Date) {
        let r = Reminder(title: title, at: date)
        reminders.append(r)
        scheduleNotification(for: r)
        save()
        onChange?()
    }

    func remove(id: String) {
        reminders.removeAll { $0.id == id }
        if notificationEnabled {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        }
        save()
        onChange?()
    }

    /// 距离现在最近的、尚未触发的提醒
    func nextReminder() -> Reminder? {
        let now = Date()
        return reminders.filter { $0.fireDate > now }.min { $0.fireDate < $1.fireDate }
    }

    /// 移除已触发的提醒（到点后不再保留在列表，通知已提醒用户）。
    /// 触发烟火是本方法的职责：先通知 onDue，再移除，保证任何调用方先执行都不会丢烟火。
    func pruneExpired() {
        let now = Date()
        for r in reminders where r.fireDate <= now && !firedDueIDs.contains(r.id) {
            firedDueIDs.insert(r.id)
            onDue?(r.title.isEmpty ? "提醒" : r.title)
        }
        let before = reminders.count
        reminders.removeAll { $0.fireDate <= now }
        if reminders.count != before {
            save()
        }
    }

    // MARK: - 通知

    private func scheduleNotification(for r: Reminder) {
        guard notificationEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = r.title.isEmpty ? "提醒" : r.title
        content.body = "时间到了"
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: r.fireDate
        )
        // 避免触发时间已过（极小概率竞态）时无效
        guard comps.date != nil else { return }
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: r.id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                NSLog("[DragReminder] 通知调度失败: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - 持久化

    private func save() {
        do {
            let data = try JSONEncoder().encode(reminders)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            NSLog("[DragReminder] 保存失败: %@", error.localizedDescription)
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            reminders = try JSONDecoder().decode([Reminder].self, from: data)
        } catch {
            NSLog("[DragReminder] 读取失败: %@", error.localizedDescription)
        }
    }
}

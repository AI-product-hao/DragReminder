import AppKit
import UserNotifications

// MARK: - 入口

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    private var statusItem: NSStatusItem!
    private let manager = ReminderManager()
    private var statusView: StatusBarView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 通知权限
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                NSLog("[DragReminder] 通知授权错误: %@", error.localizedDescription)
            }
            NSLog("[DragReminder] 通知授权: %@", granted ? "允许" : "拒绝")
        }

        // 状态栏：自定义视图直接作为状态栏项内容（保证鼠标事件到达我们的视图）
        statusItem = NSStatusBar.system.statusItem(withLength: 32)
        statusItem.menu = buildMenu()

        statusView = StatusBarView(manager: manager)
        statusView.frame = NSRect(x: 0, y: 0, width: 32, height: NSStatusBar.system.thickness)
        statusView.onMenu = { [weak self] in
            guard let self = self else { return }
            self.statusItem.popUpMenu(self.buildMenu())
        }
        statusView.onCreateReminder = { [weak self] minutes in
            guard let self = self else { return }
            self.promptCreateReminder(minutes: minutes)
        }
        statusView.onLengthChange = { [weak self] width in
            guard let self = self else { return }
            self.statusItem.length = max(32, width)
        }
        statusItem.view = statusView
    }

    // MARK: - 菜单

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let newItem = NSMenuItem(title: "新建提醒…", action: #selector(newReminder), keyEquivalent: "n")
        newItem.target = self
        menu.addItem(newItem)
        menu.addItem(.separator())

        let now = Date()
        let upcoming = manager.reminders
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }

        if upcoming.isEmpty {
            let empty = NSMenuItem(title: "暂无提醒", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for r in upcoming.prefix(10) {
                let remain = r.fireDate.timeIntervalSinceNow
                let title = r.title.isEmpty ? "提醒" : r.title
                let item = NSMenuItem(
                    title: "\(title)（剩余 \(StatusBarView.format(remain))）",
                    action: nil,
                    keyEquivalent: ""
                )
                let sub = NSMenu()
                let del = NSMenuItem(title: "删除此提醒", action: #selector(deleteReminder(_:)), keyEquivalent: "")
                del.target = self
                del.representedObject = r.id
                sub.addItem(del)
                item.submenu = sub
                menu.addItem(item)
            }
            if upcoming.count > 10 {
                let more = NSMenuItem(title: "还有 \(upcoming.count - 10) 条…", action: nil, keyEquivalent: "")
                more.isEnabled = false
                menu.addItem(more)
            }
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出拖拽提醒", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    // MARK: - 拖拽后确认创建

    /// 拖拽选定时长后，弹出对话框让用户填写任务名称，确认后才创建并开始倒计时
    private func promptCreateReminder(minutes: Double) {
        let alert = NSAlert()
        alert.messageText = "创建提醒"
        alert.informativeText = "时长：\(StatusBarView.durationText(minutes))，请输入提醒内容"
        // 弹窗图标：直接从应用包加载最新 AppIcon.icns（避免 NSImage 名称缓存返回旧图标）
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            alert.icon = icon
        }
        alert.addButton(withTitle: "开始倒计时")
        alert.addButton(withTitle: "取消")

        let nameField = NSTextField(string: "")
        nameField.placeholderString = "如：喝水、休息、给客户打电话…"
        nameField.frame = NSRect(x: 0, y: 0, width: 260, height: 24)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.addArrangedSubview(nameField)
        stack.frame = NSRect(x: 0, y: 0, width: 260, height: 32)
        alert.accessoryView = stack

        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            let title = nameField.stringValue.trimmingCharacters(in: .whitespaces)
            manager.add(title: title.isEmpty ? "提醒" : title, minutes: minutes)
        }
    }

    @objc private func newReminder() {
        let alert = NSAlert()
        alert.messageText = "新建提醒"
        alert.informativeText = "设置提醒内容与时间（分钟）"
        // 弹窗图标：直接从应用包加载最新 AppIcon.icns（避免 NSImage 名称缓存返回旧图标）
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            alert.icon = icon
        }
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")

        let descField = NSTextField(string: "")
        descField.placeholderString = "提醒内容（可留空）"
        descField.frame = NSRect(x: 0, y: 0, width: 240, height: 24)

        let minuteField = NSTextField(string: "10")
        minuteField.placeholderString = "分钟数，如 25"
        minuteField.frame = NSRect(x: 0, y: 0, width: 240, height: 24)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.addArrangedSubview(descField)
        stack.addArrangedSubview(minuteField)
        stack.frame = NSRect(x: 0, y: 0, width: 240, height: 56)
        alert.accessoryView = stack

        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            let minutes = Double(minuteField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 10
            manager.add(title: descField.stringValue, minutes: max(0.5, minutes))
        }
    }

    @objc private func deleteReminder(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        manager.remove(id: id)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - 通知前台展示

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

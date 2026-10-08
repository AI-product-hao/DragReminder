import AppKit

/// 菜单栏自定义视图：猫图标 + 倒计时文本，支持"拖拽创建提醒"手势
/// 布局跟随父视图同步，事件使用全局鼠标坐标计算拖拽距离
final class StatusBarView: NSView {

    /// 点击（非拖拽）时弹出菜单
    var onMenu: (() -> Void)?
    /// 拖拽松手时回调，参数为分钟数（由外部决定如何创建）
    var onCreateReminder: ((Double) -> Void)?
    /// 内容宽度变化时回调，用于同步菜单栏图标宽度
    var onLengthChange: ((CGFloat) -> Void)?

    private let iconView = NSImageView()
    private let countdownLabel = NSTextField(labelWithString: "")
    private let manager: ReminderManager

    // 拖拽状态（使用全局屏幕坐标）
    private var dragStartGlobalX: CGFloat = 0
    private var dragStartGlobalY: CGFloat = 0
    private var dragging = false
    // 钓鱼线指示窗口
    private var dragWindow: NSPanel?
    private var dragLineView: DragLineView?
    /// 当前钓鱼线窗口所在屏幕的原点（全局坐标），避免依赖 NSWindow.screen 的空值问题
    private var dragScreenOrigin: NSPoint = .zero
    /// 拖拽跟踪定时器（轮询鼠标位置驱动鱼线，不依赖 mouseDragged 事件）
    private var dragTrackTimer: Timer?

    /// 文件调试日志（/tmp/dragreminder_debug.log）
    private func debugLog(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }
        let url = URL(fileURLWithPath: "/tmp/dragreminder_debug.log")
        if FileManager.default.fileExists(atPath: url.path) {
            if let fh = try? FileHandle(forWritingTo: url) {
                fh.seekToEndOfFile()
                fh.write(data)
                try? fh.close()
            }
        } else {
            try? data.write(to: url)
        }
    }

    /// 拖拽比例：向下 1pt = 10 秒
    private let secondsPerPoint: CGFloat = 10
    /// 拖拽最短时长（低于此视为点击），30 秒
    private let minDragSeconds: CGFloat = 30
    /// 拖拽最长时长 6 小时
    private let maxSeconds: CGFloat = 6 * 3600

    init(manager: ReminderManager) {
        self.manager = manager
        super.init(frame: NSRect(x: 0, y: 0, width: 60, height: 22))
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 60, height: 22) }

    // MARK: - 布局（跟随父按钮，不依赖 Auto Layout 约束）

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        syncFrameToParent()
    }

    override func layout() {
        super.layout()
        syncFrameToParent()
        layoutSubviews()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    private func syncFrameToParent() {
        guard let parent = superview else { return }
        if frame != parent.bounds {
            frame = parent.bounds
            needsLayout = true
        }
    }

    private func layoutSubviews() {
        let h = bounds.height
        iconView.frame = NSRect(x: 4, y: (h - 16) / 2, width: 16, height: 16)
        if countdownLabel.stringValue.isEmpty {
            countdownLabel.frame = NSRect(x: 24, y: 0, width: 0, height: h)
        } else {
            let w = countdownLabel.intrinsicContentSize.width
            countdownLabel.frame = NSRect(x: 24, y: 0, width: w, height: h)
        }
    }

    // MARK: - 初始化

    private func setup() {
        // 菜单栏图标：彩色透明底猫头（应用自带资源），加载失败时回退到 SF Symbol
        if let path = Bundle.main.path(forResource: "cat_icon_menu", ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            img.isTemplate = false
            img.size = NSSize(width: 18, height: 18)
            iconView.image = img
            iconView.contentTintColor = nil
        } else {
            let cat = NSImage(systemSymbolName: "cat", accessibilityDescription: "拖拽提醒")
            let fallback = NSImage(systemSymbolName: "timer", accessibilityDescription: "拖拽提醒")
            if let img = cat ?? fallback {
                img.isTemplate = true
                iconView.image = img
                iconView.contentTintColor = .labelColor
            }
        }
        iconView.translatesAutoresizingMaskIntoConstraints = true
        countdownLabel.translatesAutoresizingMaskIntoConstraints = true
        countdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        countdownLabel.textColor = .labelColor
        countdownLabel.stringValue = ""

        addSubview(iconView)
        addSubview(countdownLabel)

        refreshCountdown()

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshCountdown()
        }
        RunLoop.main.add(t, forMode: .common)
    }

    // MARK: - 倒计时显示

    func refreshCountdown() {
        manager.pruneExpired()
        guard let next = manager.nextReminder() else {
            if countdownLabel.stringValue != "" {
                countdownLabel.stringValue = ""
                needsLayout = true
                onLengthChange?(28)
            }
            return
        }
        let remain = next.fireDate.timeIntervalSinceNow
        let text = remain > 0 ? Self.format(remain) : ""
        if countdownLabel.stringValue != text {
            countdownLabel.stringValue = text
            needsLayout = true
            let w = countdownLabel.intrinsicContentSize.width
            onLengthChange?(24 + w + 8)
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func durationText(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m < 1 { return "\(Int(minutes * 60)) 秒" }
        if m < 60 { return "\(m) 分钟" }
        let h = m / 60
        let rem = m % 60
        return rem == 0 ? "\(h) 小时" : "\(h) 小时 \(rem) 分钟"
    }

    // MARK: - 拖拽手势（全局坐标）

    override func mouseDown(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        dragStartGlobalX = p.x
        dragStartGlobalY = p.y
        dragging = true
        debugLog("mouseDown at \(p)")
        startDragTracking()
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragging else { return }
        let current = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(current) } ?? NSScreen.main
        guard let screen = screen else { return }
        ensureDragWindow(on: screen)
        updateDragLine()
    }

    override func mouseUp(with event: NSEvent) {
        guard dragging else { return }
        dragging = false
        stopDragTracking()
        hideDragLine()

        let currentY = NSEvent.mouseLocation.y
        let dy = dragStartGlobalY - currentY
        let seconds = min(max(0, dy * secondsPerPoint), maxSeconds)
        debugLog("mouseUp dy=\(dy) seconds=\(seconds)")

        if seconds >= minDragSeconds {
            onCreateReminder?(seconds / 60)
        } else {
            onMenu?()
        }
    }

    // MARK: - 拖拽跟踪定时器

    /// 按下后启动定时器轮询鼠标位置，实时驱动钓鱼线（不依赖 mouseDragged 事件）
    private func startDragTracking() {
        stopDragTracking()
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.dragging else { return }
            let current = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(current) }) ?? NSScreen.main else { return }
            self.ensureDragWindow(on: screen)
            self.updateDragLine()
        }
        RunLoop.main.add(t, forMode: .common)
        dragTrackTimer = t
        debugLog("startDragTracking")
    }

    private func stopDragTracking() {
        dragTrackTimer?.invalidate()
        dragTrackTimer = nil
    }

    // MARK: - 钓鱼线指示

    /// 在指定屏幕上创建（或复用）全屏钓鱼线窗口
    private func ensureDragWindow(on screen: NSScreen) {
        let origin = screen.frame.origin
        if let existing = dragWindow, dragScreenOrigin == origin {
            // 复用已创建的窗口：必须重新置前显示（否则第二次及后续拖拽窗口仍处于隐藏状态）
            existing.orderFrontRegardless()
            return
        }
        dragWindow?.orderOut(nil)
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // 关键：菜单栏应用从不激活，必须关闭"失活自动隐藏"，否则窗口会被立即隐藏
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false

        let lineView = DragLineView(frame: NSRect(origin: .zero, size: screen.frame.size))
        panel.contentView = lineView
        dragWindow = panel
        dragLineView = lineView
        dragScreenOrigin = origin
        panel.orderFrontRegardless()
        debugLog("ensureDragWindow frame=\(NSStringFromRect(panel.frame)) isVisible=\(panel.isVisible ? "YES" : "NO") origin=\(NSStringFromPoint(origin))")
    }

    /// 更新线的起终点与时间气泡（使用缓存屏幕原点，不依赖窗口 screen 属性）
    private func updateDragLine() {
        guard let lineView = dragLineView else { return }
        let origin = dragScreenOrigin
        let current = NSEvent.mouseLocation
        lineView.startPoint = NSPoint(x: dragStartGlobalX - origin.x, y: dragStartGlobalY - origin.y)
        lineView.currentPoint = NSPoint(x: current.x - origin.x, y: current.y - origin.y)
        let dy = dragStartGlobalY - current.y
        let seconds = min(max(0, dy * secondsPerPoint), maxSeconds)
        lineView.timeText = Self.durationText(seconds / 60)
        lineView.needsDisplay = true
        debugLog("updateDragLine start=\(NSStringFromPoint(lineView.startPoint)) cur=\(NSStringFromPoint(lineView.currentPoint)) text=\(lineView.timeText) winVisible=\((dragWindow?.isVisible ?? false) ? "YES" : "NO")")
    }

    private func hideDragLine() {
        dragWindow?.orderOut(nil)
    }
}

import AppKit

/// 到期提醒的全屏烟火 + 任务名称展示（约 3 秒后自动淡出消失）
///
/// 用法：FireworksOverlay.show(title: "喝水") —— 会在鼠标所在屏幕（或主屏）中央
/// 绽放一簇烟花，并把任务名称显示在屏幕中央上方，3 秒后整体淡出。
///
/// 实现说明：菜单栏应用（accessory）永不激活，CAEmitterLayer 的粒子动画时钟不会
/// 推进（实测粒子不渲染），因此采用 Timer 驱动 + 每帧自绘粒子的方案，100% 可靠。
enum FireworksOverlay {

    /// 当前活跃的烟火窗口（强引用，防止提前释放；关闭后自动移除）
    private static var activeWindows: [FireworksWindow] = []

    /// 在“当前屏幕”（鼠标所在屏幕，找不到则主屏）中央放烟火并显示任务名
    @discardableResult
    static func show(title: String) -> FireworksWindow? {
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main
        guard let s = screen else { return nil }
        let window = FireworksWindow(title: title, screen: s)
        activeWindows.append(window)
        window.onClosed = { [weak window] in
            if let w = window {
                activeWindows.removeAll { $0 === w }
            }
        }
        window.show()
        return window
    }
}

/// 覆盖单个屏幕的无边框透明顶层窗口：烟火 + 标题，3 秒后淡出关闭
final class FireworksWindow: NSWindow {

    var onClosed: (() -> Void)?

    init(title: String, screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating                    // 盖过普通窗口；screenSaver 级在个别系统可能不渲染
        ignoresMouseEvents = true            // 不拦截鼠标，不打扰用户操作
        // 关键修复：macOS 26 上 isOpaque=false 的透明窗口，其内容（draw 与 subview）
        // 不会被合成器渲染（实测不可见）。改用 isOpaque=true + clear 背景：窗口走
        // 不透明合成路径，clear 背景不影响视觉，内容全部正常显示。
        isOpaque = true
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        contentView = FireworksView(title: title)

        // 3 秒后淡出并关闭（烟火自身约 2.9 秒自然熄灭）。
        // 注意：菜单栏应用（accessory）下 AppKit/CA 动画时钟不可靠，淡出用手动 Timer 渐变。
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            var a: CGFloat = 1.0
            let fade = Timer(timeInterval: 0.04, repeats: true) { t in
                a -= 0.06
                self.alphaValue = max(0, a)
                if a <= 0 {
                    t.invalidate()
                    self.orderOut(nil)
                    self.close()
                    self.onClosed?()
                }
            }
            RunLoop.main.add(fade, forMode: .common)
        }
    }

    func show() {
        // 直接显示，不用 alphaValue 动画（AppKit 动画在 accessory app 下不推进，
        // 从 0 起步会导致窗口永远全透明不可见）
        orderFrontRegardless()
    }
}

/// 烟火渲染视图：Timer 驱动的自绘粒子烟花 + 居中的任务名称
final class FireworksView: NSView {

    /// 单个火花粒子
    private struct Particle {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var age: CGFloat = 0
        var lifetime: CGFloat
        var scale: CGFloat
        var image: CGImage
    }

    private var particles: [Particle] = []
    private var timer: Timer?
    private var startTime: Date?

    private let titleLabel = NSTextField(labelWithString: "")

    /// 预生成的彩色火花图（橙 / 金 / 粉 / 白）
    private static let sparkImages: [CGImage] = FireworksView.makeSparkImages()

    init(title: String) {
        super.init(frame: .zero)

        // ---- 任务名称 ----
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 44, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
        shadow.shadowBlurRadius = 12
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        titleLabel.shadow = shadow
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let w = bounds.width
        let h = bounds.height

        // 任务名称：屏幕中央上方（AppKit 左下原点，0.72h ≈ 视觉上部 28%）
        let labelSize = titleLabel.sizeThatFits(NSSize(width: w - 80, height: 220))
        titleLabel.frame = NSRect(
            x: (w - labelSize.width) / 2,
            y: h * 0.72,
            width: labelSize.width,
            height: labelSize.height
        )

        // 首次布局时安排烟花爆发（三簇，时间错开）
        guard particles.isEmpty, startTime == nil else { return }
        scheduleBurst(at: CGPoint(x: w * 0.5, y: h * 0.50), count: 150, delay: 0.05)
        scheduleBurst(at: CGPoint(x: w * 0.26, y: h * 0.66), count: 80, delay: 0.4)
        scheduleBurst(at: CGPoint(x: w * 0.74, y: h * 0.66), count: 80, delay: 0.7)
        startTimer()
    }

    // MARK: - 烟花爆发

    private func scheduleBurst(at point: CGPoint, count: Int, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.burst(at: point, count: count)
        }
    }

    /// 在指定点生成一簇向四周飞散的粒子
    private func burst(at p: CGPoint, count: Int) {
        for _ in 0..<count {
            // 速度方向：以向上为主，但可向全方向偏（最大偏角约 126°）
            let angle = CGFloat.random(in: (-.pi / 2 - 2.2) ... (-.pi / 2 + 2.2))
            let speed = CGFloat.random(in: 260 ... 560)
            let img = FireworksView.sparkImages.randomElement()!
            particles.append(Particle(
                x: p.x,
                y: p.y,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                lifetime: CGFloat.random(in: 1.1 ... 2.0),
                scale: CGFloat.random(in: 0.16 ... 0.34),
                image: img
            ))
        }
        needsDisplay = true
    }

    // MARK: - 动画循环（Timer 驱动，菜单栏应用下 100% 可靠）

    private func startTimer() {
        startTime = Date()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.step()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func step() {
        guard let st = startTime else { return }
        let dt = CGFloat(1.0 / 60.0)

        var alive: [Particle] = []
        for var p in particles {
            p.age += dt
            if p.age >= p.lifetime { continue }
            p.vy -= 260 * dt        // 重力
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.scale = max(0.02, p.scale - 0.03 * dt)
            alive.append(p)
        }
        particles = alive
        needsDisplay = true

        // 全部熄灭后停止动画
        if Date().timeIntervalSince(st) > 2.9 {
            timer?.invalidate()
            timer = nil
            particles.removeAll()
            needsDisplay = true
        }
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext, !particles.isEmpty else { return }

        // 注意：透明窗口上不能用 plusLighter（目标 alpha 为 0 时不累积，画了不可见），
        // 粒子贴图本身是带透明度的彩色渐变，用 normal 即可。
        for p in particles {
            let alpha = max(0, 1 - p.age / p.lifetime)
            ctx.setAlpha(alpha)
            let s = 24 * p.scale
            let rect = CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)
            ctx.draw(p.image, in: rect)
        }
        ctx.setAlpha(1)
    }

    // MARK: - 火花贴图

    /// 生成 4 张彩色径向渐变火花图
    private static func makeSparkImages() -> [CGImage] {
        let colors: [NSColor] = [
            NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.20, alpha: 1),   // 橙
            NSColor(calibratedRed: 1.00, green: 0.85, blue: 0.30, alpha: 1),   // 金
            NSColor(calibratedRed: 1.00, green: 0.45, blue: 0.60, alpha: 1),   // 粉
            NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1),   // 白
        ]
        return colors.map { color -> CGImage in
            let size = 24
            let cs = CGColorSpace(name: CGColorSpace.sRGB)!
            let ctx = CGContext(
                data: nil, width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            let clear = CGColor(colorSpace: cs, components: [1, 1, 1, 0])!
            let grad = CGGradient(
                colorsSpace: cs,
                colors: [color.cgColor, clear] as CFArray,
                locations: [0, 1]
            )!
            ctx.drawRadialGradient(
                grad,
                startCenter: CGPoint(x: size / 2, y: size / 2), startRadius: 0,
                endCenter: CGPoint(x: size / 2, y: size / 2), endRadius: CGFloat(size) / 2,
                options: []
            )
            return ctx.makeImage()!
        }
    }
}

import AppKit

/// 拖拽时全屏覆盖显示的"鱼线 + 鱼形时间"（猫吃鱼）
/// 线从按下起点（菜单栏猫图标）延伸到鼠标当前位置，末端悬挂一条橙色小鱼，鱼身上显示倒计时时长
final class DragLineView: NSView {

    /// 线的起点（面板坐标系内，即全局坐标 - 屏幕原点）
    var startPoint: NSPoint = .zero
    /// 线的末端（当前鼠标位置，面板坐标系内）
    var currentPoint: NSPoint = .zero
    /// 鱼身上显示的时间文本
    var timeText: String = "" {
        didSet { needsDisplay = true }
    }

    private var didLogDraw = false

    // 颜色
    private let bodyTop = NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.38, alpha: 0.96)
    private let bodyBottom = NSColor(calibratedRed: 0.93, green: 0.52, blue: 0.20, alpha: 0.96)
    private let finColor = NSColor(calibratedRed: 0.90, green: 0.46, blue: 0.15, alpha: 0.95)
    private let outlineColor = NSColor(calibratedRed: 0.35, green: 0.22, blue: 0.12, alpha: 0.95)
    private let textColor = NSColor(calibratedRed: 0.30, green: 0.19, blue: 0.10, alpha: 1.0)
    private let lineColor = NSColor(calibratedWhite: 1.0, alpha: 0.92)
    private let lineShadow = NSColor(calibratedWhite: 0.1, alpha: 0.30)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if !didLogDraw {
            didLogDraw = true
            let line = "[\(Date())] DragLineView.draw bounds=\(NSStringFromRect(bounds)) start=\(NSStringFromPoint(startPoint)) cur=\(NSStringFromPoint(currentPoint)) text=\(timeText)\n"
            if let data = line.data(using: .utf8) {
                let url = URL(fileURLWithPath: "/tmp/dragreminder_debug.log")
                if FileManager.default.fileExists(atPath: url.path) {
                    if let fh = try? FileHandle(forWritingTo: url) {
                        fh.seekToEndOfFile(); fh.write(data); try? fh.close()
                    }
                } else {
                    try? data.write(to: url)
                }
            }
        }
        guard !timeText.isEmpty else { return }

        let bounds = self.bounds

        // ---- 计算鱼的位置与尺寸（挂在鼠标位置上方） ----
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 22),
            .foregroundColor: textColor,
        ]
        let text = NSAttributedString(string: timeText, attributes: attr)
        let textSize = text.size()
        let fishW = max(170, textSize.width + 74)
        let fishH: CGFloat = 72

        var fishCenter = NSPoint(x: currentPoint.x, y: currentPoint.y + 26)
        if fishCenter.x < fishW / 2 + 10 { fishCenter.x = fishW / 2 + 10 }
        if fishCenter.x > bounds.width - fishW / 2 - 10 { fishCenter.x = bounds.width - fishW / 2 - 10 }
        if fishCenter.y < fishH / 2 + 10 { fishCenter.y = fishH / 2 + 10 }
        if fishCenter.y > bounds.height - fishH / 2 - 10 { fishCenter.y = bounds.height - fishH / 2 - 10 }

        // 鱼背连接点（线末端）
        let hookPoint = NSPoint(x: fishCenter.x - fishW * 0.10, y: fishCenter.y + fishH * 0.30)

        // ---- 鱼线：从起点到鱼背，带轻微自然弧度，白线+阴影保证任何背景可见 ----
        let midX = (startPoint.x + hookPoint.x) / 2
        let midY = (startPoint.y + hookPoint.y) / 2
        let control = NSPoint(x: midX + 14, y: midY + 6)

        func fishingLine(_ path: NSBezierPath) {
            path.move(to: startPoint)
            path.curve(to: hookPoint, controlPoint1: control, controlPoint2: hookPoint)
            path.lineWidth = 4
            path.lineCapStyle = .round
        }
        // 阴影线（先画）
        let shadowLine = NSBezierPath()
        fishingLine(shadowLine)
        lineShadow.setStroke()
        shadowLine.stroke()
        // 主鱼线
        let mainLine = NSBezierPath()
        fishingLine(mainLine)
        mainLine.lineWidth = 2
        lineColor.setStroke()
        mainLine.stroke()

        // ---- 鱼形时间 ----
        drawFish(center: fishCenter, width: fishW, height: fishH, text: text, textSize: textSize)
    }

    /// 绘制一条横置的卡通小鱼（头朝右、尾朝左、背鳍连鱼线），鱼身中央写时间文本
    private func drawFish(center: NSPoint, width w: CGFloat, height h: CGFloat, text: NSAttributedString, textSize: NSSize) {
        let bodyRect = NSRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)

        // 尾巴（左侧扇形）
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: bodyRect.minX, y: center.y - h * 0.24))
        tail.curve(to: NSPoint(x: bodyRect.minX - w * 0.14, y: center.y),
                   controlPoint1: NSPoint(x: bodyRect.minX - w * 0.16, y: center.y - h * 0.16),
                   controlPoint2: NSPoint(x: bodyRect.minX - w * 0.16, y: center.y))
        tail.curve(to: NSPoint(x: bodyRect.minX, y: center.y + h * 0.24),
                   controlPoint1: NSPoint(x: bodyRect.minX - w * 0.16, y: center.y),
                   controlPoint2: NSPoint(x: bodyRect.minX - w * 0.16, y: center.y + h * 0.16))
        tail.close()
        finColor.setFill()
        tail.fill()
        outlineColor.setStroke()
        tail.lineWidth = 2.5
        tail.lineJoinStyle = .round
        tail.stroke()

        // 身体（椭圆）
        let body = NSBezierPath(ovalIn: bodyRect)
        let gradient = NSGradient(starting: bodyTop, ending: bodyBottom)
        gradient?.draw(in: body, angle: -90)
        outlineColor.setStroke()
        body.lineWidth = 2.5
        body.stroke()

        // 背鳍（顶部，鱼线连接处）
        let dorsal = NSBezierPath()
        dorsal.move(to: NSPoint(x: center.x - w * 0.30, y: bodyRect.maxY))
        dorsal.curve(to: NSPoint(x: center.x - w * 0.08, y: bodyRect.maxY + h * 0.30),
                     controlPoint1: NSPoint(x: center.x - w * 0.22, y: bodyRect.maxY + h * 0.20),
                     controlPoint2: NSPoint(x: center.x - w * 0.16, y: bodyRect.maxY + h * 0.28))
        dorsal.curve(to: NSPoint(x: center.x - w * 0.02, y: bodyRect.maxY),
                     controlPoint1: NSPoint(x: center.x - w * 0.10, y: bodyRect.maxY + h * 0.22),
                     controlPoint2: NSPoint(x: center.x - w * 0.06, y: bodyRect.maxY + h * 0.05))
        dorsal.close()
        finColor.setFill()
        dorsal.fill()
        outlineColor.setStroke()
        dorsal.lineWidth = 2.5
        dorsal.lineJoinStyle = .round
        dorsal.stroke()

        // 腹鳍（底部）
        let ventral = NSBezierPath()
        ventral.move(to: NSPoint(x: center.x - w * 0.32, y: bodyRect.minY))
        ventral.curve(to: NSPoint(x: center.x - w * 0.16, y: bodyRect.minY - h * 0.22),
                      controlPoint1: NSPoint(x: center.x - w * 0.26, y: bodyRect.minY - h * 0.14),
                      controlPoint2: NSPoint(x: center.x - w * 0.22, y: bodyRect.minY - h * 0.20))
        ventral.curve(to: NSPoint(x: center.x - w * 0.06, y: bodyRect.minY),
                      controlPoint1: NSPoint(x: center.x - w * 0.12, y: bodyRect.minY - h * 0.14),
                      controlPoint2: NSPoint(x: center.x - w * 0.10, y: bodyRect.minY - h * 0.03))
        ventral.close()
        finColor.setFill()
        ventral.fill()
        outlineColor.setStroke()
        ventral.lineWidth = 2.5
        ventral.lineJoinStyle = .round
        ventral.stroke()

        // 鱼头细节：眼睛 + 高光 + 嘴（右侧）
        let eyeCenter = NSPoint(x: center.x + w * 0.28, y: center.y + h * 0.10)
        let eyeR = h * 0.15
        let eyeWhite = NSBezierPath(ovalIn: NSRect(x: eyeCenter.x - eyeR, y: eyeCenter.y - eyeR, width: eyeR * 2, height: eyeR * 2))
        NSColor.white.setFill()
        eyeWhite.fill()
        outlineColor.setStroke()
        eyeWhite.lineWidth = 2
        eyeWhite.stroke()
        let pupilR = eyeR * 0.52
        let pupil = NSBezierPath(ovalIn: NSRect(x: eyeCenter.x - pupilR, y: eyeCenter.y - pupilR, width: pupilR * 2, height: pupilR * 2))
        NSColor(calibratedRed: 0.15, green: 0.12, blue: 0.10, alpha: 1).setFill()
        pupil.fill()
        let glint = NSBezierPath(ovalIn: NSRect(x: eyeCenter.x + pupilR * 0.4, y: eyeCenter.y + pupilR * 0.4, width: pupilR * 0.55, height: pupilR * 0.55))
        NSColor.white.setFill()
        glint.fill()

        // 嘴（右侧小弧）
        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: center.x + w * 0.46, y: center.y - h * 0.02))
        mouth.curve(to: NSPoint(x: center.x + w * 0.43, y: center.y - h * 0.12),
                    controlPoint1: NSPoint(x: center.x + w * 0.49, y: center.y - h * 0.06),
                    controlPoint2: NSPoint(x: center.x + w * 0.46, y: center.y - h * 0.10))
        outlineColor.setStroke()
        mouth.lineWidth = 2.5
        mouth.lineCapStyle = .round
        mouth.stroke()

        // 时间文本（鱼身中央，非翻转坐标 at 为文本左下角）
        text.draw(at: NSPoint(x: center.x - textSize.width / 2,
                              y: center.y - textSize.height / 2 - 2))
    }
}

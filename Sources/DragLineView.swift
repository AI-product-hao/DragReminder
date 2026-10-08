import AppKit

/// 拖拽时全屏覆盖显示的"鱼线 + 鱼形时间"（猫吃鱼）
/// 线从按下起点（菜单栏猫图标）延伸到鼠标当前位置，末端悬挂一条粉色可爱小鱼，鱼身上显示倒计时时长
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

    // 颜色（粉色少女风，可爱、柔和、对比清晰）
    private let bodyTop = NSColor(calibratedRed: 1.00, green: 0.88, blue: 0.84, alpha: 0.97)     // 奶油粉
    private let bodyBottom = NSColor(calibratedRed: 0.99, green: 0.74, blue: 0.72, alpha: 0.97)  // 粉
    private let finColor = NSColor(calibratedRed: 0.98, green: 0.60, blue: 0.58, alpha: 0.96)    // 珊瑚粉
    private let outlineColor = NSColor(calibratedRed: 0.55, green: 0.36, blue: 0.28, alpha: 0.95) // 暖棕描边
    private let textColor = NSColor(calibratedRed: 0.36, green: 0.24, blue: 0.16, alpha: 1.0)    // 深暖棕文字
    private let blushColor = NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.55, alpha: 0.55)  // 腮红
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

        // ---- 计算鱼的位置与尺寸（鱼身更大，文字空间充足） ----
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: textColor,
        ]
        let text = NSAttributedString(string: timeText, attributes: attr)
        let textSize = text.size()
        // 鱼身更长：文字两侧留足空间，不贴边
        let fishW = max(300, textSize.width + 150)
        let fishH: CGFloat = 92

        var fishCenter = NSPoint(x: currentPoint.x, y: currentPoint.y + 30)
        if fishCenter.x < fishW / 2 + 10 { fishCenter.x = fishW / 2 + 10 }
        if fishCenter.x > bounds.width - fishW / 2 - 10 { fishCenter.x = bounds.width - fishW / 2 - 10 }
        if fishCenter.y < fishH / 2 + 10 { fishCenter.y = fishH / 2 + 10 }
        if fishCenter.y > bounds.height - fishH / 2 - 10 { fishCenter.y = bounds.height - fishH / 2 - 10 }

        // 背鳍顶部连接点（线末端）
        let hookPoint = NSPoint(x: fishCenter.x + fishW * 0.06, y: fishCenter.y + fishH * 0.30)

        // ---- 鱼线：从起点到背鳍，带轻微自然弧度，白线+阴影保证任何背景可见 ----
        let midX = (startPoint.x + hookPoint.x) / 2
        let midY = (startPoint.y + hookPoint.y) / 2
        let control = NSPoint(x: midX + 14, y: midY + 6)

        func fishingLine(_ path: NSBezierPath) {
            path.move(to: startPoint)
            path.curve(to: hookPoint, controlPoint1: control, controlPoint2: hookPoint)
            path.lineWidth = 4
            path.lineCapStyle = .round
        }
        let shadowLine = NSBezierPath()
        fishingLine(shadowLine)
        lineShadow.setStroke()
        shadowLine.stroke()
        let mainLine = NSBezierPath()
        fishingLine(mainLine)
        mainLine.lineWidth = 2
        lineColor.setStroke()
        mainLine.stroke()

        // ---- 鱼形时间 ----
        drawFish(center: fishCenter, width: fishW, height: fishH, text: text, textSize: textSize)
    }

    /// 绘制一条横置的粉色可爱小鱼（头朝左、尾朝右、背鳍连鱼线），鱼身中央写时间文本
    private func drawFish(center: NSPoint, width w: CGFloat, height h: CGFloat, text: NSAttributedString, textSize: NSSize) {
        let bodyRect = NSRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)

        // 尾巴（右侧扇形，圆润俏皮）
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: bodyRect.maxX, y: center.y - h * 0.20))
        tail.curve(to: NSPoint(x: bodyRect.maxX + w * 0.12, y: center.y),
                   controlPoint1: NSPoint(x: bodyRect.maxX + w * 0.14, y: center.y - h * 0.14),
                   controlPoint2: NSPoint(x: bodyRect.maxX + w * 0.14, y: center.y))
        tail.curve(to: NSPoint(x: bodyRect.maxX, y: center.y + h * 0.20),
                   controlPoint1: NSPoint(x: bodyRect.maxX + w * 0.14, y: center.y),
                   controlPoint2: NSPoint(x: bodyRect.maxX + w * 0.14, y: center.y + h * 0.14))
        tail.close()
        finColor.setFill()
        tail.fill()
        outlineColor.setStroke()
        tail.lineWidth = 3
        tail.lineJoinStyle = .round
        tail.stroke()

        // 身体（圆润椭圆）
        let body = NSBezierPath(ovalIn: bodyRect)
        let gradient = NSGradient(starting: bodyTop, ending: bodyBottom)
        gradient?.draw(in: body, angle: -90)
        outlineColor.setStroke()
        body.lineWidth = 3
        body.stroke()

        // 背鳍（顶部圆润扇形，鱼线连接处）
        let dorsal = NSBezierPath()
        dorsal.move(to: NSPoint(x: center.x - w * 0.10, y: bodyRect.maxY))
        dorsal.curve(to: NSPoint(x: center.x + w * 0.10, y: bodyRect.maxY + h * 0.30),
                     controlPoint1: NSPoint(x: center.x - w * 0.02, y: bodyRect.maxY + h * 0.20),
                     controlPoint2: NSPoint(x: center.x + w * 0.04, y: bodyRect.maxY + h * 0.28))
        dorsal.curve(to: NSPoint(x: center.x + w * 0.22, y: bodyRect.maxY),
                     controlPoint1: NSPoint(x: center.x + w * 0.14, y: bodyRect.maxY + h * 0.22),
                     controlPoint2: NSPoint(x: center.x + w * 0.18, y: bodyRect.maxY + h * 0.06))
        dorsal.close()
        finColor.setFill()
        dorsal.fill()
        outlineColor.setStroke()
        dorsal.lineWidth = 3
        dorsal.lineJoinStyle = .round
        dorsal.stroke()

        // 腹鳍（底部圆润扇形）
        let ventral = NSBezierPath()
        ventral.move(to: NSPoint(x: center.x + w * 0.14, y: bodyRect.minY))
        ventral.curve(to: NSPoint(x: center.x + w * 0.30, y: bodyRect.minY - h * 0.22),
                      controlPoint1: NSPoint(x: center.x + w * 0.20, y: bodyRect.minY - h * 0.14),
                      controlPoint2: NSPoint(x: center.x + w * 0.26, y: bodyRect.minY - h * 0.20))
        ventral.curve(to: NSPoint(x: center.x + w * 0.38, y: bodyRect.minY),
                      controlPoint1: NSPoint(x: center.x + w * 0.32, y: bodyRect.minY - h * 0.14),
                      controlPoint2: NSPoint(x: center.x + w * 0.36, y: bodyRect.minY - h * 0.03))
        ventral.close()
        finColor.setFill()
        ventral.fill()
        outlineColor.setStroke()
        ventral.lineWidth = 3
        ventral.lineJoinStyle = .round
        ventral.stroke()

        // 鱼头细节（左侧）：大眼睛 + 睫毛 + 高光 + 腮红 + 微笑嘴
        let eyeCenter = NSPoint(x: center.x - w * 0.30, y: center.y + h * 0.10)
        let eyeR = h * 0.17
        let eyeWhite = NSBezierPath(ovalIn: NSRect(x: eyeCenter.x - eyeR, y: eyeCenter.y - eyeR, width: eyeR * 2, height: eyeR * 2))
        NSColor.white.setFill()
        eyeWhite.fill()
        outlineColor.setStroke()
        eyeWhite.lineWidth = 2.5
        eyeWhite.stroke()
        // 瞳孔（大而有神）
        let pupilR = eyeR * 0.62
        let pupil = NSBezierPath(ovalIn: NSRect(x: eyeCenter.x - pupilR, y: eyeCenter.y - pupilR, width: pupilR * 2, height: pupilR * 2))
        NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.14, alpha: 1).setFill()
        pupil.fill()
        // 高光
        let glint = NSBezierPath(ovalIn: NSRect(x: eyeCenter.x + pupilR * 0.35, y: eyeCenter.y + pupilR * 0.40, width: pupilR * 0.5, height: pupilR * 0.5))
        NSColor.white.setFill()
        glint.fill()
        // 睫毛（三根，从眼睛上缘向上）
        outlineColor.setStroke()
        let lashX = eyeCenter.x - eyeR * 0.6
        let lashBaseY = eyeCenter.y + eyeR * 0.9
        for i in 0..<3 {
            let lash = NSBezierPath()
            lash.move(to: NSPoint(x: lashX + CGFloat(i) * eyeR * 0.6, y: lashBaseY))
            lash.line(to: NSPoint(x: lashX + CGFloat(i) * eyeR * 0.6 + eyeR * 0.18, y: lashBaseY + eyeR * 0.42))
            lash.lineWidth = 2.2
            lash.lineCapStyle = .round
            lash.stroke()
        }

        // 腮红（眼睛下方）
        let blushR = h * 0.12
        let blush = NSBezierPath(ovalIn: NSRect(x: eyeCenter.x - eyeR * 0.5 - blushR, y: eyeCenter.y - h * 0.22 - blushR, width: blushR * 2, height: blushR * 2))
        blushColor.setFill()
        blush.fill()

        // 微笑嘴（左侧）
        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: center.x - w * 0.42, y: center.y - h * 0.10))
        mouth.curve(to: NSPoint(x: center.x - w * 0.34, y: center.y - h * 0.20),
                    controlPoint1: NSPoint(x: center.x - w * 0.45, y: center.y - h * 0.15),
                    controlPoint2: NSPoint(x: center.x - w * 0.38, y: center.y - h * 0.19))
        outlineColor.setStroke()
        mouth.lineWidth = 2.5
        mouth.lineCapStyle = .round
        mouth.stroke()

        // 时间文本（鱼身中后部：避开左侧鱼头/眼睛，水平向右偏移约 7% 鱼宽）
        text.draw(at: NSPoint(x: center.x - textSize.width / 2 + w * 0.07,
                              y: center.y - textSize.height / 2 - 2))
    }
}

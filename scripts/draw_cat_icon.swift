import AppKit

// 绘制扁平风格的橙色猫脸应用图标，输出 1024x1024 PNG
// 用法: draw_cat_icon <输出路径.png>

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let ctx = NSGraphicsContext.current else { fatalError("无绘图上下文") }
ctx.cgContext.setShouldAntialias(true)

// 颜色
let cream   = NSColor(calibratedRed: 1.00, green: 0.96, blue: 0.90, alpha: 1)   // 奶油背景
let orange  = NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.28, alpha: 1)   // 猫橙
let dark    = NSColor(calibratedRed: 0.35, green: 0.22, blue: 0.12, alpha: 1)   // 深棕描边
let pink    = NSColor(calibratedRed: 0.98, green: 0.65, blue: 0.65, alpha: 1)   // 内耳/鼻
let black   = NSColor(calibratedRed: 0.15, green: 0.12, blue: 0.10, alpha: 1)

func triangle(_ a: NSPoint, _ b: NSPoint, _ c: NSPoint) -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: a); p.line(to: b); p.line(to: c); p.close()
    return p
}

// 1. 背景圆角矩形
let bg = NSBezierPath(roundedRect: NSRect(x: 96, y: 96, width: 832, height: 832), xRadius: 190, yRadius: 190)
cream.setFill()
bg.fill()

// 2. 左耳 + 内耳
let leftEar = triangle(NSPoint(x: 235, y: 850), NSPoint(x: 415, y: 715), NSPoint(x: 205, y: 630))
orange.setFill(); dark.setStroke()
leftEar.lineWidth = 22; leftEar.lineJoinStyle = .round
leftEar.fill(); leftEar.stroke()
let leftInner = triangle(NSPoint(x: 262, y: 795), NSPoint(x: 383, y: 705), NSPoint(x: 252, y: 652))
pink.setFill()
leftInner.fill()

// 3. 右耳 + 内耳
let rightEar = triangle(NSPoint(x: 789, y: 850), NSPoint(x: 609, y: 715), NSPoint(x: 819, y: 630))
orange.setFill(); dark.setStroke()
rightEar.lineWidth = 22; rightEar.lineJoinStyle = .round
rightEar.fill(); rightEar.stroke()
let rightInner = triangle(NSPoint(x: 762, y: 795), NSPoint(x: 641, y: 705), NSPoint(x: 772, y: 652))
pink.setFill()
rightInner.fill()

// 4. 头（圆）
let head = NSBezierPath(ovalIn: NSRect(x: 172, y: 130, width: 680, height: 680))
orange.setFill(); dark.setStroke()
head.lineWidth = 22
head.fill(); head.stroke()

// 5. 眼睛
func eye(_ cx: CGFloat, _ cy: CGFloat) {
    let white = NSBezierPath(ovalIn: NSRect(x: cx - 85, y: cy - 85, width: 170, height: 170))
    NSColor.white.setFill()
    white.fill()
    dark.setStroke(); white.lineWidth = 14
    white.stroke()
    let pupil = NSBezierPath(ovalIn: NSRect(x: cx - 38, y: cy - 32, width: 76, height: 76))
    black.setFill()
    pupil.fill()
    let glint = NSBezierPath(ovalIn: NSRect(x: cx - 56, y: cy + 4, width: 26, height: 26))
    NSColor.white.setFill()
    glint.fill()
}
eye(390, 520)
eye(634, 520)

// 6. 鼻子
let nose = triangle(NSPoint(x: 512, y: 468), NSPoint(x: 464, y: 408), NSPoint(x: 560, y: 408))
pink.setFill(); dark.setStroke()
nose.lineWidth = 12; nose.lineJoinStyle = .round
nose.fill(); nose.stroke()

// 7. 嘴（W 形，两条弧线）
func mouthArc(_ to: NSPoint, _ c1: NSPoint, _ c2: NSPoint) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: 512, y: 418))
    p.curve(to: to, controlPoint1: c1, controlPoint2: c2)
    p.lineWidth = 12; p.lineCapStyle = .round
    dark.setStroke()
    p.stroke()
}
mouthArc(NSPoint(x: 428, y: 378), NSPoint(x: 490, y: 348), NSPoint(x: 448, y: 382))
mouthArc(NSPoint(x: 596, y: 378), NSPoint(x: 534, y: 348), NSPoint(x: 576, y: 382))

// 8. 胡须
func whisker(_ x: CGFloat, _ y: CGFloat, _ dx: CGFloat, _ dy: CGFloat) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: x, y: y))
    p.line(to: NSPoint(x: x + dx, y: y + dy))
    p.lineWidth = 10; p.lineCapStyle = .round
    dark.setStroke()
    p.stroke()
}
whisker(200, 432, -92, 12)
whisker(210, 380, -95, 0)
whisker(214, 328, -88, -12)
whisker(824, 432, 92, 12)
whisker(814, 380, 95, 0)
whisker(810, 328, 88, -12)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG 生成失败")
}
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/cat_icon_1024.png")
try png.write(to: out)
print("已生成: \(out.path)")

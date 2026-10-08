import AppKit

// 将方案2扁平猫图标（白底+浅橙圆环+橙色方块猫）处理为透明背景
// 仅保留橙色方块猫主体，作为弹窗图标使用（填满、无白边）
// 用法: clear_bg <输入.png> <输出.png>

guard CommandLine.arguments.count >= 3,
      let img = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fatalError("参数或读取失败")
}

// 先绘制到带 alpha 的画布，确保 RGBA
let canvas = NSImage(size: img.size)
canvas.lockFocus()
img.draw(in: NSRect(origin: .zero, size: img.size))
canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else {
    fatalError("转换失败")
}

let w = rep.pixelsWide
let h = rep.pixelsHigh

var visited = [[Bool]](repeating: [Bool](repeating: false, count: w), count: h)
var queue: [(Int, Int)] = []
func seed(_ x: Int, _ y: Int) {
    if x >= 0 && x < w && y >= 0 && y < h && !visited[y][x] {
        visited[y][x] = true
        queue.append((x, y))
    }
}
for x in 0..<w { seed(x, 0); seed(x, h - 1) }
for y in 0..<h { seed(0, y); seed(w - 1, y) }

// 近白：背景
func nearWhite(_ c: NSColor) -> Bool {
    c.redComponent > 0.90 && c.greenComponent > 0.90 && c.blueComponent > 0.90
}
// 浅橙圆环（与方块橙区分：g、b 更高）
func ringOrange(_ c: NSColor) -> Bool {
    c.redComponent > 0.96 && c.greenComponent > 0.64 && c.greenComponent < 0.95 &&
    c.blueComponent > 0.42 && c.blueComponent < 0.86
}

while let (x, y) = queue.popLast() {
    guard let c = rep.colorAt(x: x, y: y) else { continue }
    if nearWhite(c) || ringOrange(c) {
        rep.setColor(NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0), atX: x, y: y)
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let nx = x + dx, ny = y + dy
            if nx >= 0 && nx < w && ny >= 0 && ny < h && !visited[ny][nx] {
                visited[ny][nx] = true
                queue.append((nx, ny))
            }
        }
    }
}

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG 输出失败")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("已生成: \(CommandLine.arguments[2])")

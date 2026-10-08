import AppKit

// 自动裁剪透明边距，让主体占满画布（弹窗图标显示更大、与系统弹窗图标一致）
// 用法: trim_alpha <输入.png> <输出.png>

guard CommandLine.arguments.count >= 3,
      let img = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else {
    fatalError("参数或读取失败")
}

let w = rep.pixelsWide
let h = rep.pixelsHigh
var minX = w, maxX = -1, minY = h, maxY = -1

for y in 0..<h {
    for x in 0..<w {
        if let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.03 {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
    }
}
print("边界 minX=\(minX) maxX=\(maxX) minY=\(minY) maxY=\(maxY)")

guard maxX >= minX, maxY >= minY else { fatalError("未找到内容") }
let cropRect = NSRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)

// 用 NSImage 从源图按区域绘制裁剪结果
let croppedImage = NSImage(size: cropRect.size)
croppedImage.lockFocus()
img.draw(in: NSRect(origin: .zero, size: cropRect.size), from: cropRect, operation: .copy, fraction: 1.0)
croppedImage.unlockFocus()

guard let tiff2 = croppedImage.tiffRepresentation,
      let outRep = NSBitmapImageRep(data: tiff2),
      let png = outRep.representation(using: .png, properties: [:]) else { fatalError("PNG 输出失败") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("已生成: \(CommandLine.arguments[2])（\(cropRect.width)x\(cropRect.height)）")

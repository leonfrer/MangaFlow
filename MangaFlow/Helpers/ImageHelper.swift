import SwiftUI
import UniformTypeIdentifiers

class ImageHelper {
    static func mergeImages(_ imagePath1: String, _ imagePath2: String) -> NSImage? {
        // 加载图片并添加错误处理
        guard let image1 = NSImage(contentsOfFile: imagePath1),
            let image2 = NSImage(contentsOfFile: imagePath2)
        else {
            print("无法加载图片: \(imagePath1) 或 \(imagePath2)")
            return nil
        }

        // 从 TIFF 数据创建 NSBitmapImageRep，确保兼容性
        guard let tiff1 = image1.tiffRepresentation,
            let tiff2 = image2.tiffRepresentation,
            let rep1 = NSBitmapImageRep(data: tiff1),
            let rep2 = NSBitmapImageRep(data: tiff2)
        else {
            print("无法获取图片的位图表示")
            return nil
        }

        // 获取实际像素尺寸
        let pixelsWide1 = rep1.pixelsWide
        let pixelsHigh1 = rep1.pixelsHigh
        let pixelsWide2 = rep2.pixelsWide
        let pixelsHigh2 = rep2.pixelsHigh

        // 计算新图尺寸
        let totalWidth = pixelsWide1 + pixelsWide2
        let maxHeight = max(pixelsHigh1, pixelsHigh2)

        // 创建高分辨率画布
        guard
            let mergedRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: totalWidth,
                pixelsHigh: maxHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: totalWidth * 4,
                bitsPerPixel: 32
            )
        else {
            print("无法创建合并后的位图表示")
            return nil
        }

        // 开始绘制
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: mergedRep)

        // 绘制第一张图（垂直居中）
        let y1 = (maxHeight - pixelsHigh1) / 2
        rep1.draw(in: NSRect(x: 0, y: y1, width: pixelsWide1, height: pixelsHigh1))

        // 绘制第二张图（垂直居中）
        let y2 = (maxHeight - pixelsHigh2) / 2
        rep2.draw(in: NSRect(x: pixelsWide1, y: y2, width: pixelsWide2, height: pixelsHigh2))

        NSGraphicsContext.restoreGraphicsState()

        // 创建并返回合并后的图片
        let mergedImage = NSImage()
        mergedImage.addRepresentation(mergedRep)
        return mergedImage
    }

    static func rotateNSImage(imagePath: String, angle: CGFloat) -> NSImage? {
        // 讀取圖片
        guard let image = NSImage(contentsOfFile: imagePath) else {
            print("❌ 無法加載圖片：\(imagePath)")
            return nil
        }

        // 取得 CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ 無法獲取 CGImage")
            return nil
        }

        let radians = angle * CGFloat.pi / 180
        let imageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))

        // 計算旋轉後的新尺寸
        let newSize = CGRect(origin: .zero, size: imageSize)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size

        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSColorSpaceName.deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep!)?.cgContext else {
            print("❌ 無法創建圖形上下文")
            return nil
        }

        // 執行旋轉
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        context.translateBy(x: -imageSize.width / 2, y: -imageSize.height / 2)

        context.draw(cgImage, in: CGRect(origin: .zero, size: imageSize))

        // 轉換為 NSImage
        let rotatedImage = NSImage(size: newSize)
        rotatedImage.addRepresentation(bitmapRep!)

        return rotatedImage
    }
}

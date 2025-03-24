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

    static func rotateNSImage(imagePath: String, angle: CGFloat) -> URL? {
        let url = URL(fileURLWithPath: imagePath)
        let ext = url.pathExtension.lowercased()

        let newUrl = replaceFilenameWithUUID(fileURL: url)

        if ext == "jpg" || ext == "jpeg" {
            rotateJPGLosslessly(inputURL: url, outputURL: newUrl, angle: 90)
        } else if ext == "png" {
            rotatePNG(inputURL: url, outputURL: newUrl, angle: 90)
        } else {
            return nil
        }

        return newUrl
    }

    private static func replaceFilenameWithUUID(fileURL: URL) -> URL {
        let fileExtension = fileURL.pathExtension  // 獲取文件後綴
        let newFilename = UUID().uuidString  // 生成 UUID
        let newFilenameWithExt =
            fileExtension.isEmpty ? newFilename : "\(newFilename).\(fileExtension)"

        return fileURL.deletingLastPathComponent().appendingPathComponent(newFilenameWithExt)
    }

    private static func rotateJPGLosslessly(inputURL: URL, outputURL: URL, angle: Int) {
        guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            print("無法加載圖片")
            return
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let exifOrientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1

        let newOrientation: UInt32
        switch angle {
        case 90: newOrientation = 8  // EXIF: 逆時針 90 度旋轉
        case 180: newOrientation = 3  // EXIF: 逆時針 180 度旋轉
        case 270: newOrientation = 6  // EXIF: 逆時針 270 度旋轉
        default: newOrientation = exifOrientation
        }

        guard
            let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else {
            print("無法創建輸出文件")
            return
        }

        let options: [CFString: Any] = [kCGImagePropertyOrientation: newOrientation]
        CGImageDestinationAddImageFromSource(destination, imageSource, 0, options as CFDictionary)
        CGImageDestinationFinalize(destination)

        print("旋轉完成: \(outputURL.path)")
    }

    private static func rotatePNG(inputURL: URL, outputURL: URL, angle: CGFloat) {
        guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            print("無法加載圖片")
            return
        }

        let radians = -angle * (.pi / 180)  // macOS 坐標系是反向的，這裡取負號來變成順時針旋轉
        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)

        // 計算旋轉後的畫布大小
        let newSize = CGSize(
            width: abs(originalSize.width * cos(radians)) + abs(originalSize.height * sin(radians)),
            height: abs(originalSize.width * sin(radians)) + abs(originalSize.height * cos(radians))
        )

        // 建立 Core Graphics 透明畫布
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard
            let context = CGContext(
                data: nil,
                width: Int(newSize.width),
                height: Int(newSize.height),
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            print("無法創建畫布")
            return
        }

        // 變換坐標系，確保旋轉後圖片居中
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        context.translateBy(x: -originalSize.width / 2, y: -originalSize.height / 2)

        // 繪製原始圖片
        context.draw(cgImage, in: CGRect(origin: .zero, size: originalSize))

        // 取得旋轉後的圖片
        guard let rotatedCGImage = context.makeImage() else {
            print("旋轉失敗")
            return
        }

        // 轉換為 NSImage
        let rotatedImage = NSImage(cgImage: rotatedCGImage, size: newSize)

        // 儲存為 PNG
        guard let pngData = rotatedImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: pngData),
            let finalData = bitmap.representation(using: .png, properties: [:])
        else {
            print("無法轉換為 PNG")
            return
        }

        do {
            try finalData.write(to: outputURL)
            print("PNG 旋轉完成: \(outputURL.path)")
        } catch {
            print("保存 PNG 失敗: \(error)")
        }
    }

}

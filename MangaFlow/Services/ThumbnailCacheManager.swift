import Combine
import SwiftUI

class ThumbnailCacheManager: ObservableObject {
    // Singleton instance for easy access across the app
    static let shared = ThumbnailCacheManager()

    // Published property that will notify observers when changed
    @Published var cache: [String: NSImage] = [:]

    func loadThumbnail(path: String) {
        if cache[path] != nil {
            return
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            if let fullImage = NSImage(contentsOf: URL(fileURLWithPath: path)) {
                // 创建并缓存缩略图
                let size = fullImage.size
                let thumbnail = resizeImage(
                    image: fullImage, targetSize: NSSize(width: size.width, height: size.height))
                DispatchQueue.main.async {
                    self.cache[path] = thumbnail
                }
            }
        }
    }

    func resizeImage(image: NSImage, targetSize: NSSize) -> NSImage {
        // 创建一个新的、正确尺寸的图像
        let resizedImage = NSImage(size: targetSize)

        // 计算保持比例的绘制区域
        let imageSize = image.size
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height

        // 选择较小的比例以确保图像完全适合目标尺寸
        let scaleFactor = min(widthRatio, heightRatio)

        let scaledWidth = imageSize.width * scaleFactor
        let scaledHeight = imageSize.height * scaleFactor

        // 计算居中绘制的起始点
        let x = (targetSize.width - scaledWidth) / 2.0
        let y = (targetSize.height - scaledHeight) / 2.0

        // 绘制图像
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        // 清除背景（可选，如果需要透明背景）
        NSColor.clear.set()
        NSRect(origin: .zero, size: targetSize).fill()

        // 绘制缩放后居中的图像
        image.draw(
            in: NSRect(x: x, y: y, width: scaledWidth, height: scaledHeight),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0)

        resizedImage.unlockFocus()
        return resizedImage
    }

}

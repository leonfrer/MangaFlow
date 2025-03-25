import SwiftUI

struct ImageThumbnail: View {
    let path: String
    let isSelected: Bool
    @Binding var thumbnailCache: [String: NSImage]
    let onTap: () -> Void

    var body: some View {
        Group {
            if let cachedImage = thumbnailCache[path] {
                let imageSize = cachedImage.size
                let aspectRatio = imageSize.width / imageSize.height

                Image(nsImage: cachedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: aspectRatio >= 1 ? 80 : 80 * aspectRatio,
                        height: aspectRatio <= 1 ? 80 : 80 / aspectRatio
                    )
                    .padding(4)
                    .onTapGesture(perform: onTap)
                    .border(isSelected ? Color.blue : Color.gray, width: 2)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .padding(4)
                    .border(Color.gray, width: 2)
                    .onAppear {
                        loadThumbnail(path: path)
                    }
            }
        }
    }

    private func loadThumbnail(path: String) {
        DispatchQueue.global(qos: .background).async {
            if let fullImage = NSImage(contentsOf: URL(fileURLWithPath: path)) {
                // 创建并缓存缩略图
                let thumbnail = resizeImage(
                    image: fullImage, targetSize: NSSize(width: 160, height: 160))
                DispatchQueue.main.async {
                    thumbnailCache[path] = thumbnail
                }
            }
        }
    }

    private func resizeImage(image: NSImage, targetSize: NSSize) -> NSImage {
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

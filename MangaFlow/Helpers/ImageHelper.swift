import SwiftUI
import UniformTypeIdentifiers

func mergeImages(_ imagePath1: String, _ imagePath2: String) -> NSImage? {
    // 使用 NSBitmapImageRep 獲取實際像素尺寸
    guard let image1 = NSImage(contentsOfFile: imagePath1),
          let image2 = NSImage(contentsOfFile: imagePath2),
          let rep1 = image1.representations.first as? NSBitmapImageRep,
          let rep2 = image2.representations.first as? NSBitmapImageRep
    else { return nil }
    
    // 取得實際像素尺寸
    let pixelsWide1 = rep1.pixelsWide
    let pixelsHigh1 = rep1.pixelsHigh
    let pixelsWide2 = rep2.pixelsWide
    let pixelsHigh2 = rep2.pixelsHigh
    
    // 計算新圖片尺寸
    let totalWidth = pixelsWide1 + pixelsWide2
    let maxHeight = max(pixelsHigh1, pixelsHigh2)
    
    // 創建高解析度畫布
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
    )!
    
    // 開始繪製
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: mergedRep)
    
    // 繪製第一張圖（垂直居中）
    let y1 = (maxHeight - pixelsHigh1) / 2
    rep1.draw(in: NSRect(x: 0, y: y1, width: pixelsWide1, height: pixelsHigh1))
    
    // 繪製第二張圖（垂直居中）
    let y2 = (maxHeight - pixelsHigh2) / 2
    rep2.draw(in: NSRect(x: pixelsWide1, y: y2, width: pixelsWide2, height: pixelsHigh2))
    
    NSGraphicsContext.restoreGraphicsState()
    
    // 組合最終圖片
    let mergedImage = NSImage()
    mergedImage.addRepresentation(mergedRep)
    return mergedImage
}

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedImage: NSImage? = nil
    @State private var imageNames: [String] = []
    @State private var previewHeight: CGFloat = 300
    @State private var selectedIndex: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let selectedImage = selectedImage {
                    Image(nsImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: previewHeight)
                        .padding()
                } else {
                    Text("Select an image")
                        .foregroundColor(.gray)
                        .font(.title)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Thumbnail Image Area
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(imageNames.indices, id: \.self) { index in
                        if let nsImage = NSImage(
                            contentsOf: URL(fileURLWithPath: imageNames[index]))
                        {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .padding(4)
                                .onTapGesture {
                                    selectedImage = nsImage
                                    selectedIndex = index
                                }
                                .border(selectedIndex == index ? Color.blue : Color.gray, width: 2)
                        }
                    }
                }
                .padding()
            }
            .frame(height: 100)
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItemGroup {
                Button(action: rotateImage) {
                    Label("旋轉", systemImage: "rotate.left")
                }
                .disabled(selectedImage == nil)
                Button(action: mergeWithLeft) {
                    Label("與左邊合併", systemImage: "arrow.left.square")
                }
                .disabled(selectedIndex == nil || selectedIndex == 0)  // 第一張圖不能與左邊合併

                Button(action: mergeWithRight) {
                    Label("與右邊合併", systemImage: "arrow.right.square")
                }
                .disabled(selectedIndex == nil || selectedIndex == imageNames.count - 1)  // 最後一張圖不能與右邊合併

                Picker
                
                Button(action: openFilePicker) {
                    Label("添加圖片", systemImage: "plus.viewfinder")
                }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        updateLayout(for: geometry.size)
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        updateLayout(for: newSize)
                    }
            }
        )
        .onChange(of: imageNames) { oldValue, newValue in
            if oldValue.count == 0 && selectedImage == nil {
                if let firstImagePath = imageNames.first,
                    let firstImage = NSImage(contentsOf: URL(fileURLWithPath: firstImagePath))
                {
                    selectedImage = firstImage
                    selectedIndex = 0
                }
            }
        }
    }

    private func updateLayout(for size: CGSize) {
        previewHeight = size.height * 0.7
    }

    private func openFilePicker() {
        let dialog = NSOpenPanel()
        dialog.allowsMultipleSelection = true
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowedContentTypes = [UTType.png, UTType.jpeg]

        if dialog.runModal() == .OK {
            let urls = FileManagerHelper.importImagesToTemporarySandbox(from: dialog.urls)
            let selectedFiles = urls
            for file in selectedFiles {
                // 將選擇的圖片路徑加入到列表中
                imageNames.append(file.path)
            }
        }
    }

    // 與左邊的圖片合併
    private func mergeWithLeft() {
        guard let index = selectedIndex, index > 0 else { return }
        let leftImagePath = imageNames[index - 1]
        let currentImagePath = imageNames[index]

        if let mergedImage = mergeImages(leftImagePath, currentImagePath) {
            saveMergedImage(mergedImage, at: index, to: index - 1)
        }
    }

    // 與右邊的圖片合併
    private func mergeWithRight() {
        guard let index = selectedIndex, index < imageNames.count - 1 else { return }
        let currentImagePath = imageNames[index]
        let rightImagePath = imageNames[index + 1]

        if let mergedImage = mergeImages(currentImagePath, rightImagePath) {
            saveMergedImage(mergedImage, at: index, to: index + 1)
        }
    }

    private func saveMergedImage(_ image: NSImage, at index: Int, to anotherIndex: Int) {
        guard let tiffData = image.tiffRepresentation,
            let bitmapRep = NSBitmapImageRep(data: tiffData),
            let pngData = bitmapRep.representation(using: .png, properties: [:])
        else { return }

        do {
            // 強制使用 PNG 格式保存以保持無損
            let originalURL = URL(fileURLWithPath: imageNames[index])
            let pngURL = originalURL.deletingPathExtension().appendingPathExtension("png")
            try pngData.write(to: pngURL)

            // 更新列表為新 PNG 文件
            imageNames[index] = pngURL.path
            try FileManager.default.removeItem(at: originalURL)
            try FileManager.default.removeItem(at: URL(fileURLWithPath: imageNames[anotherIndex]))

            // 刷新圖片
            selectedImage = image

        } catch {
            print("保存失敗: \(error)")
        }
    }

    private func rotateImage() {
        guard let index = selectedIndex else { return }
        let imagePath = imageNames[index]
        guard let rotatedImage = rotateNSImage(imagePath: imagePath, angle: 90)
        else { return }

        // 取得原圖片的格式（副檔名）
        let fileExtension = (imagePath as NSString).pathExtension.lowercased()

        // 轉換為 TIFF（用來生成不同格式）
        guard let tiffData = rotatedImage.tiffRepresentation,
            let bitmapRep = NSBitmapImageRep(data: tiffData)
        else {
            print("❌ 無法轉換為位圖格式")
            return
        }

        // 根據原始格式選擇保存方式
        let imageData: Data?

        switch fileExtension {
        case "png":
            imageData = bitmapRep.representation(using: .png, properties: [:])
        case "jpg", "jpeg":
            imageData = bitmapRep.representation(
                using: .jpeg, properties: [.compressionFactor: 1.0])
        case "tiff":
            imageData = tiffData
        default:
            print("⚠️ 不支持的格式：\(fileExtension)")
            return
        }

        guard let finalImageData = imageData else {
            print("❌ 無法生成最終圖片數據")
            return
        }

        // 覆蓋原圖片
        do {
            try finalImageData.write(to: URL(fileURLWithPath: imagePath))
            print("✅ 成功覆蓋圖片：\(imagePath) (格式：\(fileExtension))")
        } catch {
            print("❌ 無法保存圖片：\(error)")
            return
        }

        selectedImage = rotatedImage
    }
}

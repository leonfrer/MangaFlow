import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedImage: NSImage? = nil
    @State private var imageNames: [String] = []
    @State private var previewHeight: CGFloat = 300
    @State private var selectedIndex: Int? = nil
    @State private var ltr = true
    @FocusState private var isFocused: Bool

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
            .onTapGesture {
                if var index = selectedIndex, index < imageNames.count - 1 {
                    index += 1
                    selectedIndex = index
                }
            }

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
                                    selectedIndex = index
                                }
                                .border(selectedIndex == index ? Color.blue : Color.gray, width: 2)
                        }
                    }
                }
                .environment(\.layoutDirection, ltr ? .leftToRight : .rightToLeft)
                .padding()
            }
            .frame(height: 100)
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItemGroup {
                Toggle(
                    "翻页方向",
                    systemImage: "book.pages",
                    isOn: $ltr
                )
                .environment(\.layoutDirection, ltr ? .leftToRight : .rightToLeft)
                Button(action: rotateImage) {
                    Label("旋轉", systemImage: "rotate.left")
                }
                .disabled(selectedImage == nil)
                Button(action: mergeWithLeft) {
                    Label("與左邊合併", systemImage: "arrow.left.square")
                }
                .disabled(selectedIndex == nil || selectedIndex == (ltr ? 0 : imageNames.count - 1))  // 第一張圖不能與左邊合併

                Button(action: mergeWithRight) {
                    Label("與右邊合併", systemImage: "arrow.right.square")
                }
                .disabled(selectedIndex == nil || selectedIndex == (ltr ? imageNames.count - 1 : 0))  // 最後一張圖不能與右邊合併

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
                selectedIndex = 0
            }
        }
        .onChange(of: selectedIndex) { _, newValue in
            if let index = newValue, index >= 0, index < imageNames.count {
                if let nsImage = NSImage(contentsOf: URL(fileURLWithPath: imageNames[index])) {
                    selectedImage = nsImage
                }
            }
        }
        .focusable(true)
        .focusEffectDisabled()
        .onAppear {
            // 延迟确保视图加载完成后获取焦点
            DispatchQueue.main.async {
                isFocused = true
            }
        }
        .onKeyPress { keyPress in
            switch keyPress.key {
            case .leftArrow:
                guard let index = selectedIndex else { return .handled }

                let newIndex = ltr ? index - 1 : index + 1
                let validRange = 0..<imageNames.count

                guard validRange ~= newIndex else { return .ignored }

                selectedIndex = newIndex
                return .handled
            case .rightArrow:
                guard let index = selectedIndex else { return .handled }

                let newIndex = ltr ? index + 1 : index - 1
                let validRange = 0..<imageNames.count

                guard validRange ~= newIndex else { return .ignored }

                selectedIndex = newIndex
                return .handled
            default:
                return .ignored
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
        let leftIndex = ltr ? index - 1 : index + 1
        let leftImagePath = imageNames[leftIndex]
        let currentImagePath = imageNames[index]

        if let mergedImage = mergeImages(leftImagePath, currentImagePath) {
            saveMergedImage(mergedImage, at: index, to: leftIndex)
        }
    }

    // 與右邊的圖片合併
    private func mergeWithRight() {
        guard let index = selectedIndex, index < imageNames.count - 1 else { return }
        let currentImagePath = imageNames[index]
        let rightIndex = ltr ? index + 1 : index - 1
        let rightImagePath = imageNames[rightIndex]

        if let mergedImage = mergeImages(currentImagePath, rightImagePath) {
            saveMergedImage(mergedImage, at: index, to: rightIndex)
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

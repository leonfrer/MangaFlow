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
                Button(action: { ZipHelper.createAndSaveZip(filePathList: imageNames) }) {
                    Label("导出", systemImage: "square.and.arrow.up.on.square")
                }
                .disabled(imageNames.count == 0)
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

    // 与左边的图片合并
    private func mergeWithLeft() {
        guard let index = selectedIndex, index > 0, index < imageNames.count else {
            print("索引无效或无左边图片")
            return
        }
        let leftIndex = ltr ? index - 1 : index + 1
        guard leftIndex >= 0, leftIndex < imageNames.count else { return }

        let leftImagePath = imageNames[leftIndex]
        let currentImagePath = imageNames[index]

        if let mergedImage = ImageHelper.mergeImages(leftImagePath, currentImagePath) {
            saveMergedImage(mergedImage, at: index, to: leftIndex, isLeftMerge: true)
        }
    }

    // 与右边的图片合并
    private func mergeWithRight() {
        guard let index = selectedIndex, index < imageNames.count - 1 else {
            print("索引无效或无右边图片")
            return
        }
        let rightIndex = ltr ? index + 1 : index - 1
        guard rightIndex >= 0, rightIndex < imageNames.count else { return }

        let currentImagePath = imageNames[index]
        let rightImagePath = imageNames[rightIndex]

        if let mergedImage = ImageHelper.mergeImages(currentImagePath, rightImagePath) {
            saveMergedImage(mergedImage, at: index, to: rightIndex, isLeftMerge: false)
        }
    }

    private func saveMergedImage(
        _ image: NSImage, at index: Int, to anotherIndex: Int, isLeftMerge: Bool
    ) {
        guard let tiffData = image.tiffRepresentation,
            let bitmapRep = NSBitmapImageRep(data: tiffData),
            let pngData = bitmapRep.representation(using: .png, properties: [:])
        else {
            print("无法生成 PNG 数据")
            return
        }

        do {
            // 根据合并方向决定保存位置
            let saveIndex = isLeftMerge ? min(index, anotherIndex) : min(index, anotherIndex)
            let removeIndex = isLeftMerge ? max(index, anotherIndex) : max(index, anotherIndex)
            let originalURL = URL(fileURLWithPath: imageNames[saveIndex])

            // 生成唯一文件名，避免冲突
            let fileName = originalURL.deletingPathExtension().lastPathComponent
            let directory = originalURL.deletingLastPathComponent()
            let uniqueName = "\(fileName)_\(UUID().uuidString).png"
            let pngURL = directory.appendingPathComponent(uniqueName)

            // 保存新文件
            try pngData.write(to: pngURL)

            // 删除原始文件
            let originalAnotherURL = URL(fileURLWithPath: imageNames[removeIndex])
            if FileManager.default.fileExists(atPath: originalURL.path) {
                try FileManager.default.removeItem(at: originalURL)
            }
            if FileManager.default.fileExists(atPath: originalAnotherURL.path) {
                try FileManager.default.removeItem(at: originalAnotherURL)
            }

            // 更新 imageNames 数组并移除多余项
            imageNames[saveIndex] = pngURL.path
            imageNames.remove(at: removeIndex)

            // 更新 selectedIndex
            if let currentSelected = selectedIndex {
                selectedIndex =
                    currentSelected > removeIndex ? currentSelected - 1 : currentSelected
                if selectedIndex == removeIndex { selectedIndex = saveIndex }
            }

            // 刷新图片
            selectedImage = image

        } catch {
            print("保存失败: \(error)")
        }
    }

    private func rotateImage() {
        guard let index = selectedIndex else { return }
        let imagePath = imageNames[index]
        guard let url = ImageHelper.rotateNSImage(imagePath: imagePath, angle: 90)
        else { return }
        imageNames[index] = url.absoluteString
        guard let image = NSImage(contentsOf: url) else {
            return
        }
        selectedImage = image
    }
}

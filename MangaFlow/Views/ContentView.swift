import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    // MARK: - State Properties
    @State private var selectedImage: NSImage? = nil
    @State private var imageNames: [String] = []
    @State private var previewHeight: CGFloat = 300
    @State private var selectedIndex: Int? = nil
    @ObservedObject var config = ConfigManager.shared
    @FocusState private var isFocused: Bool

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Main Image View
            imagePreviewArea

            Divider()

            // MARK: Thumbnail Gallery
            thumbnailGallery
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            toolbarItems
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
            updateSelectedImage()
        }
        .focusable(true)
        .focusEffectDisabled()
        .onAppear {
            // Delay to ensure view is loaded before focusing
            DispatchQueue.main.async {
                isFocused = true
            }
        }
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
    }

    // MARK: - View Components

    private var imagePreviewArea: some View {
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
            handleImageTap()
        }
    }

    private var thumbnailGallery: some View {
        Group {
            if imageNames.isEmpty {
                EmptyView()
            } else {
                HStack {
                    if !config.ltr {
                        Spacer()
                    }

                    ScrollViewReader { scrollProxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 8) {
                                ForEach(imageNames.indices, id: \.self) { index in
                                    ImageThumbnail(
                                        path: imageNames[index],
                                        isSelected: selectedIndex == index,
                                        onTap: { selectedIndex = index }
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(height: 100)
                        .onChange(of: selectedIndex) { _, newIndex in
                            scrollToSelectedThumbnail(proxy: scrollProxy)
                        }
                    }

                    if config.ltr {
                        Spacer()
                    }
                }
                .environment(\.layoutDirection, config.ltr ? .leftToRight : .rightToLeft)
            }
        }
    }

    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup {
            Button(action: { ZipHelper.createAndSaveZip(filePathList: imageNames) }) {
                Label("导出", systemImage: "square.and.arrow.up.on.square")
            }
            .disabled(imageNames.count == 0)

            Toggle(
                "翻页方向",
                systemImage: "book.pages",
                isOn: $config.ltr
            )
            .environment(\.layoutDirection, config.ltr ? .leftToRight : .rightToLeft)

            Button(action: rotateImage) {
                Label("旋轉", systemImage: "rotate.left")
            }
            .disabled(selectedImage == nil)

            Button(action: mergeWithLeft) {
                Label("與左邊合併", systemImage: "arrow.left.square")
            }
            .disabled(
                selectedIndex == nil || selectedIndex == (config.ltr ? 0 : imageNames.count - 1)
            )

            Button(action: mergeWithRight) {
                Label("與右邊合併", systemImage: "arrow.right.square")
            }
            .disabled(
                selectedIndex == nil || selectedIndex == (config.ltr ? imageNames.count - 1 : 0)
            )

            Button(action: openFilePicker) {
                Label("添加圖片", systemImage: "plus.viewfinder")
            }
        }
    }

    // MARK: - Methods

    private func updateLayout(for size: CGSize) {
        previewHeight = size.height * 0.7
    }

    private func handleImageTap() {
        if var index = selectedIndex, index < imageNames.count - 1 {
            index += 1
            selectedIndex = index
        }
    }

    private func scrollToSelectedThumbnail(proxy: ScrollViewProxy) {
        if let index = selectedIndex {
            withAnimation {
                proxy.scrollTo(index, anchor: .center)
            }
        }
    }

    private func updateSelectedImage() {
        if let index = selectedIndex, index >= 0, index < imageNames.count {
            if let nsImage = NSImage(contentsOf: URL(fileURLWithPath: imageNames[index])) {
                selectedImage = nsImage
            }
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .leftArrow:
            guard let index = selectedIndex else { return .handled }

            let newIndex = config.ltr ? index - 1 : index + 1
            let validRange = 0..<imageNames.count

            guard validRange ~= newIndex else { return .ignored }

            selectedIndex = newIndex
            return .handled

        case .rightArrow:
            guard let index = selectedIndex else { return .handled }

            let newIndex = config.ltr ? index + 1 : index - 1
            let validRange = 0..<imageNames.count

            guard validRange ~= newIndex else { return .ignored }

            selectedIndex = newIndex
            return .handled

        default:
            return .ignored
        }
    }

    // MARK: - Image Operations

    private func openFilePicker() {
        let dialog = NSOpenPanel()
        dialog.allowsMultipleSelection = true
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowedContentTypes = [UTType.png, UTType.jpeg]

        if dialog.runModal() == .OK {
            let urls = FileManagerHelper.importImagesToTemporarySandbox(from: dialog.urls)
            for file in urls {
                imageNames.append(file.path)
            }
        }
    }

    private func mergeWithLeft() {
        guard let index = selectedIndex, index > 0, index < imageNames.count else {
            print("索引无效或无左边图片")
            return
        }
        let leftIndex = config.ltr ? index - 1 : index + 1
        guard leftIndex >= 0, leftIndex < imageNames.count else { return }

        let leftImagePath = imageNames[leftIndex]
        let currentImagePath = imageNames[index]

        if let mergedImage = ImageHelper.mergeImages(leftImagePath, currentImagePath) {
            saveMergedImage(mergedImage, at: index, to: leftIndex, isLeftMerge: true)
        }
    }

    private func mergeWithRight() {
        guard let index = selectedIndex, index < imageNames.count - 1 else {
            print("索引无效或无右边图片")
            return
        }
        let rightIndex = config.ltr ? index + 1 : index - 1
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
            // Determine save position based on merge direction
            let saveIndex = isLeftMerge ? min(index, anotherIndex) : min(index, anotherIndex)
            let removeIndex = isLeftMerge ? max(index, anotherIndex) : max(index, anotherIndex)
            let originalURL = URL(fileURLWithPath: imageNames[saveIndex])

            // Generate unique filename to avoid conflicts
            let fileName = originalURL.deletingPathExtension().lastPathComponent
            let directory = originalURL.deletingLastPathComponent()
            let uniqueName = "\(fileName)_\(UUID().uuidString).png"
            let pngURL = directory.appendingPathComponent(uniqueName)

            // Save new file
            try pngData.write(to: pngURL)

            // Delete original files
            let originalAnotherURL = URL(fileURLWithPath: imageNames[removeIndex])
            if FileManager.default.fileExists(atPath: originalURL.path) {
                try FileManager.default.removeItem(at: originalURL)
            }
            if FileManager.default.fileExists(atPath: originalAnotherURL.path) {
                try FileManager.default.removeItem(at: originalAnotherURL)
            }

            // Update imageNames array and remove extra item
            imageNames[saveIndex] = pngURL.path
            imageNames.remove(at: removeIndex)

            // Update selectedIndex
            if let currentSelected = selectedIndex {
                selectedIndex =
                    currentSelected > removeIndex ? currentSelected - 1 : currentSelected
                if selectedIndex == removeIndex { selectedIndex = saveIndex }
            }

            // Refresh image
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
        
        let newPath = url.absoluteString
        imageNames.remove(at: index)
        imageNames.insert(newPath, at: index)
        guard let image = NSImage(contentsOf: url) else {
            return
        }
        selectedImage = image

        // // 立即为新图像生成缩略图并添加到缓存中
        // DispatchQueue.global(qos: .userInitiated).async {
        //     // 创建缩略图
        //     let thumbnail = ThumbnailCacheManager.shared.resizeImage(
        //         image: image,
        //         targetSize: NSSize(width: 160, height: 160)
        //     )

        //     // 在主线程更新缓存
        //     DispatchQueue.main.async {
        //         ThumbnailCacheManager.shared.cache[newPath] = thumbnail
        //         // 如果需要，可以发送通知触发 UI 更新
        //     }
        // }
    }
}

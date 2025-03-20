import SwiftUI
import ZIPFoundation

class ZipHelper {
    static func createAndSaveZip(filePathList: [String]) {
        let size = filePathList.count
        guard size > 0 else {
            print("没有文件可打包")
            return
        }

        // 计算编号的位数 d
        let d = Int(floor(log10(Double(size)))) + 2

        // 创建临时 ZIP 文件路径
        let tempZipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".zip")

        do {
            // 创建 ZIP 归档
            let archive = try Archive(url: tempZipURL, accessMode: .create)

            // 遍历 filePathList，添加文件到 ZIP
            for (i, path) in filePathList.enumerated() {
                let url = URL(fileURLWithPath: path)  // 将路径转为 URL
                let extensionName = url.pathExtension  // 获取文件后缀
                let numberString = String(format: "%0\(d)d", i + 1)  // 生成编号，如 "001"
                let newName = numberString + "." + extensionName  // 新文件名，如 "001.jpg"

                // 将文件添加到 ZIP，使用新文件名
                try archive.addEntry(with: newName, fileURL: url)
            }

            // 使用 NSSavePanel 让用户选择保存位置
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.zip]
            savePanel.nameFieldStringValue = "images.zip"  // 默认文件名

            savePanel.begin { response in
                if response == .OK, let destinationURL = savePanel.url {
                    do {
                        // 将临时 ZIP 文件复制到用户选择的位置
                        try FileManager.default.copyItem(at: tempZipURL, to: destinationURL)
                        // 删除临时文件
                        try FileManager.default.removeItem(at: tempZipURL)
                    } catch {
                        print("保存 ZIP 文件失败: \(error)")
                    }
                }
            }
        } catch {
            print("创建 ZIP 文件失败: \(error)")
        }
    }
}

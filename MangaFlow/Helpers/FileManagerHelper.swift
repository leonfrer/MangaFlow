import Foundation

struct FileManagerHelper {
    static let fileManager = FileManager.default
    static var openFileHandles: [URL: FileHandle] = [:]  // 存儲打開的文件句柄

    /// 獲取應用的專用臨時文件夾 (`tmp/MangaFlow/`)
    static func getAppTempDirectory() -> URL {
        let tmpDir = fileManager.temporaryDirectory
        let appTempDir = tmpDir.appendingPathComponent("MangaFlow", isDirectory: true)

        // 如果文件夾不存在，創建它
        if !fileManager.fileExists(atPath: appTempDir.path) {
            do {
                try fileManager.createDirectory(at: appTempDir, withIntermediateDirectories: true)
            } catch {
                print("❌ 無法創建臨時文件夾: \(error)")
            }
        }
        return appTempDir
    }

    static func importImagesToTemporarySandbox(from urls: [URL]) -> [URL] {
        var resultUrls = [URL]()
        for url in urls {
            if let url = importImageToTemporarySandbox(from: url) {
                resultUrls.append(url)
            }
        }
        return resultUrls
    }

    /// 把選擇的圖片存入 `tmp/MangaFlow/` 目錄
    static func importImageToTemporarySandbox(from url: URL) -> URL? {
        let appTempDir = getAppTempDirectory()

        // 生成唯一的文件名
        let fileExtension = url.pathExtension
        let uniqueFileName = UUID().uuidString + (fileExtension.isEmpty ? "" : ".\(fileExtension)")
        let destinationURL = appTempDir.appendingPathComponent(uniqueFileName)

        // 複製文件到 `tmp/MangaFlow/`
        do {
            try fileManager.copyItem(at: url, to: destinationURL)

            // 打開文件，保持引用，防止系統刪除
            let fileHandle = try FileHandle(forReadingFrom: destinationURL)
            openFileHandles[destinationURL] = fileHandle

            print("✅ 已導入圖片: \(destinationURL.path)")
            return destinationURL
        } catch {
            print("❌ 無法複製文件到臨時目錄: \(error)")
            return nil
        }
    }

    /// 應用退出時關閉所有文件句柄並刪除 `tmp/MangaFlow/`
    static func cleanupTemporaryFiles() {
        // 關閉所有文件句柄
        for (_, handle) in openFileHandles {
            handle.closeFile()
        }
        openFileHandles.removeAll()

        // 刪除整個 `tmp/MyAppImages/` 文件夾
        let appTempDir = getAppTempDirectory()
        do {
            try fileManager.removeItem(at: appTempDir)
            print("🗑 已刪除 `tmp/MangaFlow/` 及其所有內容")
        } catch {
            print("❌ 無法刪除 `tmp/MangaFlow/`: \(error)")
        }
    }
}

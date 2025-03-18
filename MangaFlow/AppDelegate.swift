import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        print("🗑 應用退出，刪除 `tmp/MyAppImages/` 內的所有文件...")
        FileManagerHelper.cleanupTemporaryFiles()
    }
}


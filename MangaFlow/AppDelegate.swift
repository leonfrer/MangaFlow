import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

  func applicationWillTerminate(_ notification: Notification) {
    NSLog("应用即将终止，开始清理文件...")

    // 模拟清理临时文件
    FileManagerHelper.cleanupTemporaryFiles()

    NSLog("清理完成")
  }
}

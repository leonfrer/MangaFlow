import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("应用启动，开始读取配置...")

    // 设置并读取配置
    //    ConfigManager.shared.setupConfigFile()
    //
    //    if let config = ConfigManager.shared.readConfig() {
    //      print("成功读取配置: \(config)")
    //    } else {
    //      print("读取配置失败")
    //    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    NSLog("应用即将终止，开始清理文件...")

    // 模拟清理临时文件
    FileManagerHelper.cleanupTemporaryFiles()

    NSLog("清理完成")
  }
}

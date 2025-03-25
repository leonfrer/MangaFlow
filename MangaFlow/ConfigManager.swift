import Cocoa

class ConfigManager: ObservableObject {
	static let shared = ConfigManager()

	@Published var ltr: Bool = false

	private init() {
		setupConfigFile()
		loadConfig()
	}

	// 文档目录中配置文件的URL
	private var configFileURL: URL {
		FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("MangaFlow")
			.appendingPathComponent("Config.plist")
	}

	// 检查并复制配置文件到应用支持目录
	private func setupConfigFile() {
		// 创建目录（如果不存在）
		let directoryURL = configFileURL.deletingLastPathComponent()
		if !FileManager.default.fileExists(atPath: directoryURL.path) {
			do {
				try FileManager.default.createDirectory(
					at: directoryURL,
					withIntermediateDirectories: true
				)
				print("创建配置目录: \(directoryURL.path)")
			} catch {
				print("创建目录失败: \(error.localizedDescription)")
				return
			}
		}

		// 如果配置文件不存在，则从Bundle中复制
		if !FileManager.default.fileExists(atPath: configFileURL.path) {
			if let bundlePath = Bundle.main.path(forResource: "Config", ofType: "plist") {
				do {
					try FileManager.default.copyItem(
						atPath: bundlePath,
						toPath: configFileURL.path
					)
					print("配置文件已复制到: \(configFileURL.path)")
				} catch {
					print("复制配置文件失败: \(error.localizedDescription)")
				}
			} else {
				print("Bundle中找不到Config.plist文件")
			}
		} else {
			print("配置文件已存在: \(configFileURL.path)")
		}
	}

	private func loadConfig() {
		do {
            let data = try Data(contentsOf: configFileURL)
            if let plistDict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                // 解析 plist 字典并更新属性
                self.ltr = plistDict["ltr"] as? Bool ?? false
            }
        } catch {
            print("Error loading configuration: \(error)")
        }
	}

	func updateConfig<T>(keyPath: ReferenceWritableKeyPath<ConfigManager, T>, value: T) {
        self[keyPath: keyPath] = value
        saveConfiguration()
    }

	private func saveConfiguration() {
        
        let plistDict: [String: Any] = [
			"ltr": ltr
        ]
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
            try data.write(to: configFileURL)
            print("Configuration saved successfully")
        } catch {
            print("Error saving configuration: \(error)")
        }
    }
}

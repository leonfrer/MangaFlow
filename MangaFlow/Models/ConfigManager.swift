import SwiftUI
import Combine

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    @Published var ltr: Bool {
        didSet {
            UserDefaults.standard.set(ltr, forKey: "readingDirectionLTR")
        }
    }
    
    private init() {
        // Load reading direction from UserDefaults or default to left-to-right
        self.ltr = UserDefaults.standard.bool(forKey: "readingDirectionLTR", defaultValue: true)
    }
}

// Extension to provide defaultValue parameter to UserDefaults.bool
extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if self.object(forKey: key) == nil {
            return defaultValue
        }
        return self.bool(forKey: key)
    }
}
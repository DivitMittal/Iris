import Foundation
import CoreGraphics

class PreferencesManager {

    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    // Preference keys
    private enum Keys {
        static let windowSize = "com.iris.app.windowSize"
        static let windowX = "com.iris.app.windowX"
        static let windowY = "com.iris.app.windowY"
        static let windowVisible = "com.iris.app.windowVisible"
        static let selectedCameraID = "com.iris.app.selectedCameraID"
        static let selectedMicrophoneID = "com.iris.app.selectedMicrophoneID"
        static let launchAtLogin = "com.iris.app.launchAtLogin"
        static let firstLaunch = "com.iris.app.firstLaunch"
    }

    // MARK: - Window Size
    var windowSize: CGFloat {
        get {
            let size = defaults.double(forKey: Keys.windowSize)
            return size > 0 ? CGFloat(size) : 200.0 // Default 200
        }
        set {
            defaults.set(Double(newValue), forKey: Keys.windowSize)
        }
    }

    // MARK: - Window Position
    var windowPosition: CGPoint {
        get {
            let x = defaults.double(forKey: Keys.windowX)
            let y = defaults.double(forKey: Keys.windowY)
            return CGPoint(x: x, y: y)
        }
        set {
            defaults.set(Double(newValue.x), forKey: Keys.windowX)
            defaults.set(Double(newValue.y), forKey: Keys.windowY)
        }
    }

    // MARK: - Window Visibility
    var windowVisible: Bool {
        get {
            // Default to true on first launch
            if isFirstLaunch {
                return true
            }
            return defaults.bool(forKey: Keys.windowVisible)
        }
        set {
            defaults.set(newValue, forKey: Keys.windowVisible)
        }
    }

    // MARK: - Camera Selection
    var selectedCameraID: String? {
        get {
            defaults.string(forKey: Keys.selectedCameraID)
        }
        set {
            defaults.set(newValue, forKey: Keys.selectedCameraID)
        }
    }

    // MARK: - Microphone Selection
    var selectedMicrophoneID: String? {
        get {
            defaults.string(forKey: Keys.selectedMicrophoneID)
        }
        set {
            defaults.set(newValue, forKey: Keys.selectedMicrophoneID)
        }
    }

    // MARK: - Launch at Login
    var launchAtLogin: Bool {
        get {
            defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }

    // MARK: - First Launch
    var isFirstLaunch: Bool {
        get {
            !defaults.bool(forKey: Keys.firstLaunch)
        }
        set {
            // Set to true means it's NOT first launch anymore
            defaults.set(!newValue, forKey: Keys.firstLaunch)
        }
    }

    // MARK: - Initialization
    private init() {
        // Mark that we've launched
        if isFirstLaunch {
            // Set defaults for first launch
            windowSize = 200.0
            windowVisible = true
            isFirstLaunch = false
        }
    }
}

import Cocoa
import AVFoundation
import ServiceManagement

class MenuBarController: NSObject {

    // MARK: - Properties
    private var statusItem: NSStatusItem?
    private weak var circularWindow: CircularWindow?
    private var cameraManager: CameraManager
    private var audioManager: AudioManager?

    // MARK: - Initialization
    init(cameraManager: CameraManager) {
        self.cameraManager = cameraManager
        super.init()

        // Observe camera device changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(devicesDidChange),
            name: .AVCaptureDeviceWasConnected,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(devicesDidChange),
            name: .AVCaptureDeviceWasDisconnected,
            object: nil
        )
    }

    func setAudioManager(_ audioManager: AudioManager) {
        self.audioManager = audioManager
        // Refresh menu
        statusItem?.menu = createMenu()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup
    func setupMenuBar() {
        debugLog("setupMenuBar() called")

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        debugLog("statusItem created: \(statusItem != nil)")

        guard let statusItem = statusItem else {
            debugLog("ERROR - statusItem is nil!")
            return
        }
        guard let button = statusItem.button else {
            debugLog("ERROR - button is nil!")
            return
        }
        debugLog("button obtained")

        // Set icon - use circle symbol as menu bar icon
        if let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Iris") {
            image.isTemplate = true
            button.image = image
        } else {
            // Fallback to text
            button.title = "●"
        }

        // Set tooltip
        button.toolTip = "Iris - Click to toggle window"

        // Set action - click to toggle
        button.action = #selector(statusItemClicked)
        button.target = self

        // Set menu for right-click
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.menu = createMenu()
    }

    func setWindow(_ window: CircularWindow) {
        self.circularWindow = window
        // Refresh menu
        statusItem?.menu = createMenu()
    }

    // MARK: - Menu Creation
    func createMenu() -> NSMenu {
        let menu = NSMenu()

        // Toggle window item
        let toggleTitle: String
        if circularWindow == nil {
            toggleTitle = "Show Window (Loading...)"
        } else if circularWindow?.isVisible == true {
            toggleTitle = "Hide Window"
        } else {
            toggleTitle = "Show Window"
        }

        let toggleItem = NSMenuItem(
            title: toggleTitle,
            action: #selector(toggleWindow),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.isEnabled = circularWindow != nil
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Camera selection submenu
        let cameraMenuItem = NSMenuItem(title: "Camera", action: nil, keyEquivalent: "")
        let cameraSubmenu = createCameraSubmenu()
        cameraMenuItem.submenu = cameraSubmenu
        menu.addItem(cameraMenuItem)

        // Sound indicator submenu
        let microphoneMenuItem = NSMenuItem(title: "Sound Indicator", action: nil, keyEquivalent: "")
        let microphoneSubmenu = createMicrophoneSubmenu()
        microphoneMenuItem.submenu = microphoneSubmenu
        menu.addItem(microphoneMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at login
        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Iris",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func createCameraSubmenu() -> NSMenu {
        let menu = NSMenu()

        let cameras = CameraManager.availableCameras()

        if cameras.isEmpty {
            let noCamera = NSMenuItem(title: "No Camera Available", action: nil, keyEquivalent: "")
            noCamera.isEnabled = false
            menu.addItem(noCamera)
            return menu
        }

        let currentDevice = cameraManager.currentDevice

        for camera in cameras {
            let item = NSMenuItem(
                title: camera.localizedName,
                action: #selector(selectCamera(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = camera

            // Checkmark for current camera
            if camera.uniqueID == currentDevice?.uniqueID {
                item.state = .on
            }

            menu.addItem(item)
        }

        return menu
    }

    private func createMicrophoneSubmenu() -> NSMenu {
        let menu = NSMenu()

        let currentDevice = audioManager?.currentDevice

        // Disable indicator option
        let disabledItem = NSMenuItem(
            title: "Disable Indicator",
            action: #selector(selectMicrophone(_:)),
            keyEquivalent: ""
        )
        disabledItem.target = self
        disabledItem.representedObject = AudioDevice.disabled
        if currentDevice?.uid == "disabled" {
            disabledItem.state = .on
        }
        menu.addItem(disabledItem)

        menu.addItem(NSMenuItem.separator())

        // System Default option
        let defaultItem = NSMenuItem(
            title: "System Default",
            action: #selector(selectMicrophone(_:)),
            keyEquivalent: ""
        )
        defaultItem.target = self
        defaultItem.representedObject = AudioDevice.systemDefault
        if currentDevice?.uid == "system-default" {
            defaultItem.state = .on
        }
        menu.addItem(defaultItem)

        let microphones = AudioManager.availableMicrophones()

        if !microphones.isEmpty {
            menu.addItem(NSMenuItem.separator())

            for mic in microphones {
                let item = NSMenuItem(
                    title: mic.name,
                    action: #selector(selectMicrophone(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = mic

                // Checkmark for current microphone (only if not using system default or disabled)
                if currentDevice?.uid != "system-default" &&
                   currentDevice?.uid != "disabled" &&
                   mic.id == currentDevice?.id {
                    item.state = .on
                }

                menu.addItem(item)
            }
        }

        return menu
    }

    // MARK: - Actions
    @objc func statusItemClicked() {
        toggleWindow()
    }

    @objc func toggleWindow() {
        guard let window = circularWindow else {
            // Window not ready yet
            return
        }

        if window.isVisible {
            window.hide()
        } else {
            window.show()
        }

        // Update menu
        statusItem?.menu = createMenu()
    }

    @objc func selectCamera(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AVCaptureDevice else { return }

        Task {
            do {
                try await cameraManager.switchToCamera(device)

                // Update menu checkmarks on main thread
                await MainActor.run {
                    self.statusItem?.menu = self.createMenu()
                }
            } catch {
                // Show error alert on main thread
                await MainActor.run {
                    self.showError("Failed to switch camera: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func selectMicrophone(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AudioDevice else { return }
        guard let audioManager = audioManager else { return }

        Task {
            do {
                try await audioManager.switchToMicrophone(device)

                // Update menu checkmarks on main thread
                await MainActor.run {
                    self.statusItem?.menu = self.createMenu()
                }
            } catch {
                // Show error alert on main thread
                await MainActor.run {
                    self.showError("Failed to switch microphone: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled() {
            disableLaunchAtLogin()
        } else {
            enableLaunchAtLogin()
        }
        // Refresh menu to update checkbox
        statusItem?.menu = createMenu()
    }

    @objc func quit() {
        // Clean up camera resources
        cameraManager.stopSession()

        // Clean up audio resources
        audioManager?.stopMonitoring()

        // Quit app
        NSApplication.shared.terminate(nil)
    }

    @objc func devicesDidChange() {
        // Refresh camera submenu
        statusItem?.menu = createMenu()
    }

    // MARK: - Launch at Login
    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return PreferencesManager.shared.launchAtLogin
        }
    }

    private func enableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                PreferencesManager.shared.launchAtLogin = true
            } catch {
                showError("Failed to enable launch at login: \(error.localizedDescription)")
            }
        } else {
            // Fallback for older macOS versions
            PreferencesManager.shared.launchAtLogin = true
            showError("Launch at login requires macOS 13 or later.")
        }
    }

    private func disableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.unregister()
                PreferencesManager.shared.launchAtLogin = false
            } catch {
                showError("Failed to disable launch at login: \(error.localizedDescription)")
            }
        } else {
            PreferencesManager.shared.launchAtLogin = false
        }
    }

    // MARK: - Error Handling
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func debugLog(_ message: String) {
        let logMessage = "[\(Date())] MenuBar: \(message)\n"
        let logPath = "/tmp/iris_debug.log"

        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let handle = FileHandle(forWritingAtPath: logPath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: logPath, contents: data, attributes: nil)
            }
        }
    }
}

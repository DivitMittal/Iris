import Foundation
import AVFoundation
import CoreAudio

enum AudioError: Error, LocalizedError {
    case permissionDenied
    case noDeviceAvailable
    case engineStartFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access denied. Enable in System Settings > Privacy & Security > Microphone."
        case .noDeviceAvailable:
            return "No microphone device found."
        case .engineStartFailed:
            return "Failed to start audio monitoring."
        }
    }
}

struct AudioDevice: Equatable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let isSystemDefault: Bool

    init(id: AudioDeviceID, name: String, uid: String, isSystemDefault: Bool = false) {
        self.id = id
        self.name = name
        self.uid = uid
        self.isSystemDefault = isSystemDefault
    }

    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        return lhs.id == rhs.id
    }

    // Special "System Default" device
    static var systemDefault: AudioDevice {
        AudioDevice(id: 0, name: "System Default", uid: "system-default", isSystemDefault: true)
    }

    // Special "Disabled" device
    static var disabled: AudioDevice {
        AudioDevice(id: 0, name: "Disabled", uid: "disabled", isSystemDefault: false)
    }
}

class AudioManager: NSObject {

    // MARK: - Properties
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var currentDeviceID: AudioDeviceID?
    private var useSystemDefault: Bool = true
    private var isDisabled: Bool = false
    private var defaultDeviceListener: AudioObjectPropertyListenerProc?
    private var shouldBeMonitoring: Bool = false  // Tracks if window wants monitoring

    var audioLevelCallback: ((Float) -> Void)?
    var isMonitoring: Bool { audioEngine?.isRunning ?? false }
    var currentDevice: AudioDevice? {
        if isDisabled {
            return AudioDevice.disabled
        }
        if useSystemDefault {
            return AudioDevice.systemDefault
        }
        guard let deviceID = currentDeviceID else { return nil }
        return Self.availableMicrophones().first { $0.id == deviceID }
    }

    // MARK: - Setup
    func setup() async throws {
        // Check permissions first
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                throw AudioError.permissionDenied
            }
        case .denied, .restricted:
            throw AudioError.permissionDenied
        @unknown default:
            throw AudioError.permissionDenied
        }

        // Create audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        // Get default input device
        currentDeviceID = Self.getDefaultInputDeviceID()

        // Restore saved preference, default to disabled
        let savedUID = PreferencesManager.shared.selectedMicrophoneID
        if savedUID == "system-default" {
            isDisabled = false
            useSystemDefault = true
        } else if let uid = savedUID, uid != "disabled",
                  let savedDevice = Self.availableMicrophones().first(where: { $0.uid == uid }) {
            isDisabled = false
            useSystemDefault = false
            currentDeviceID = savedDevice.id
        } else {
            // Default to disabled (including nil/first launch)
            isDisabled = true
            useSystemDefault = false
        }

        // Listen for default device changes
        setupDefaultDeviceListener()
    }

    private func setupDefaultDeviceListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Add listener for default device changes
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.handleDefaultDeviceChange()
        }
    }

    private func handleDefaultDeviceChange() {
        guard useSystemDefault && !isDisabled else { return }

        let wasMonitoring = isMonitoring
        if wasMonitoring {
            stopMonitoring()
        }

        // Update to new default device
        currentDeviceID = Self.getDefaultInputDeviceID()

        // Recreate audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        if wasMonitoring {
            startMonitoring()
        }
    }

    // MARK: - Monitoring Control
    func startMonitoring() {
        shouldBeMonitoring = true

        // Don't monitor if disabled
        guard !isDisabled else {
            // Send zero level
            DispatchQueue.main.async { [weak self] in
                self?.audioLevelCallback?(0)
            }
            return
        }

        guard let audioEngine = audioEngine,
              let inputNode = inputNode else { return }

        // Don't start if already running
        guard !audioEngine.isRunning else { return }

        let format = inputNode.outputFormat(forBus: 0)

        // Ensure valid format
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            print("Invalid audio format")
            return
        }

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
        }
    }

    func stopMonitoring() {
        shouldBeMonitoring = false

        guard let audioEngine = audioEngine else { return }

        if audioEngine.isRunning {
            inputNode?.removeTap(onBus: 0)
            audioEngine.stop()
        }
    }

    // MARK: - Audio Processing
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        let stride = buffer.stride

        // Calculate RMS (root mean square) for audio level
        var sumOfSquares: Float = 0
        for i in Swift.stride(from: 0, to: frameLength, by: stride) {
            let sample = channelDataValue[i]
            sumOfSquares += sample * sample
        }

        let rms = sqrt(sumOfSquares / Float(frameLength))

        // Convert to decibels and normalize to 0-1 range
        let avgPower = 20 * log10(max(rms, 0.000001))
        let minDb: Float = -60
        let maxDb: Float = 0
        let normalizedLevel = max(0, min(1, (avgPower - minDb) / (maxDb - minDb)))

        DispatchQueue.main.async { [weak self] in
            self?.audioLevelCallback?(normalizedLevel)
        }
    }

    // MARK: - Device Enumeration
    static func availableMicrophones() -> [AudioDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &audioDevices
        )

        guard status == noErr else { return [] }

        // Filter to input devices, excluding aggregate devices
        return audioDevices.compactMap { deviceID -> AudioDevice? in
            guard hasInputChannels(deviceID) else { return nil }
            let name = getDeviceName(deviceID)
            let uid = getDeviceUID(deviceID)

            // Filter out aggregate devices and system devices
            let lowercaseName = name.lowercased()
            if lowercaseName.contains("aggregate") ||
               lowercaseName.contains("cadefaultdevice") ||
               uid.contains("aggregate") {
                return nil
            }

            return AudioDevice(id: deviceID, name: name, uid: uid)
        }
    }

    // MARK: - Device Switching
    func switchToMicrophone(_ device: AudioDevice) async throws {
        // Remember if the window wants monitoring (don't reset this flag)
        let wantsMonitoring = shouldBeMonitoring

        // Stop current monitoring without clearing shouldBeMonitoring
        if isMonitoring {
            guard let audioEngine = audioEngine else { return }
            if audioEngine.isRunning {
                inputNode?.removeTap(onBus: 0)
                audioEngine.stop()
            }
        }

        // Handle special cases
        if device.uid == "disabled" {
            isDisabled = true
            useSystemDefault = false
            PreferencesManager.shared.selectedMicrophoneID = "disabled"
            // Send zero level when disabled
            DispatchQueue.main.async { [weak self] in
                self?.audioLevelCallback?(0)
            }
            return
        } else if device.uid == "system-default" {
            isDisabled = false
            useSystemDefault = true
            currentDeviceID = Self.getDefaultInputDeviceID()
            PreferencesManager.shared.selectedMicrophoneID = "system-default"
        } else {
            isDisabled = false
            useSystemDefault = false
            currentDeviceID = device.id
            PreferencesManager.shared.selectedMicrophoneID = device.uid
        }

        // Recreate audio engine with new device
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        // Restart monitoring if the window wants it
        if wantsMonitoring {
            startMonitoring()
        }
    }

    func disable() {
        Task {
            try? await switchToMicrophone(AudioDevice.disabled)
        }
    }

    // MARK: - CoreAudio Helpers
    private static func getDefaultInputDeviceID() -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        return status == noErr ? deviceID : nil
    }

    private static func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)

        guard status == noErr && dataSize > 0 else { return false }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
        defer { bufferListPointer.deallocate() }

        status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferListPointer)

        guard status == noErr else { return false }

        let bufferList = bufferListPointer.pointee
        return bufferList.mNumberBuffers > 0 && bufferList.mBuffers.mNumberChannels > 0
    }

    private static func getDeviceName(_ deviceID: AudioDeviceID) -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &name)

        return status == noErr ? name as String : "Unknown Device"
    }

    private static func getDeviceUID(_ deviceID: AudioDeviceID) -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uid: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &uid)

        return status == noErr ? uid as String : ""
    }
}

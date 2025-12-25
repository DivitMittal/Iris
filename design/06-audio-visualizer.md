# Design: Audio Visualizer

## Overview
Add an audio visualizer that displays a green wavy line around the circle's edge responding to microphone input, along with microphone selection in the menu bar.

## Goals
- Display real-time audio visualization on the circle edge
- Green wavy line that responds to microphone input
- Support microphone selection
- Efficient resource management (start/stop with window visibility)
- Handle microphone permissions gracefully

## Architecture

### AudioManager Class

```swift
class AudioManager: NSObject {
    // MARK: - Properties
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var currentDeviceID: AudioDeviceID?

    var audioLevelCallback: ((Float) -> Void)?
    var isMonitoring: Bool { audioEngine?.isRunning ?? false }

    // MARK: - Initialization
    func setup() async throws

    // MARK: - Monitoring Control
    func startMonitoring()
    func stopMonitoring()

    // MARK: - Device Enumeration
    static func availableMicrophones() -> [AudioDevice]

    // MARK: - Device Switching
    func switchToMicrophone(_ device: AudioDevice) async throws
}

struct AudioDevice {
    let id: AudioDeviceID
    let name: String
    let isDefault: Bool
}
```

## Key Components

### 1. Permission Handling

**Info.plist Entry:**
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Iris uses microphone to display audio visualization.</string>
```

**Permission Check:**
```swift
let status = AVCaptureDevice.authorizationStatus(for: .audio)
switch status {
case .authorized:
    // Proceed with setup
case .notDetermined:
    let granted = await AVCaptureDevice.requestAccess(for: .audio)
case .denied, .restricted:
    // Show error, visualization disabled
}
```

### 2. Audio Engine Setup

```swift
func setup() async throws {
    // Check permission
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    if status == .notDetermined {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        if !granted { throw AudioError.permissionDenied }
    } else if status != .authorized {
        throw AudioError.permissionDenied
    }

    // Create audio engine
    audioEngine = AVAudioEngine()
    inputNode = audioEngine?.inputNode
}
```

### 3. Real-Time Audio Level Monitoring

```swift
func startMonitoring() {
    guard let audioEngine = audioEngine,
          let inputNode = inputNode else { return }

    let format = inputNode.outputFormat(forBus: 0)

    // Install tap on input node
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }

        // Calculate RMS (root mean square) for audio level
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))

        // Convert to decibels and normalize to 0-1 range
        let avgPower = 20 * log10(rms)
        let minDb: Float = -80
        let normalizedLevel = max(0, min(1, (avgPower - minDb) / -minDb))

        DispatchQueue.main.async {
            self?.audioLevelCallback?(normalizedLevel)
        }
    }

    do {
        try audioEngine.start()
    } catch {
        print("Failed to start audio engine: \(error)")
    }
}

func stopMonitoring() {
    inputNode?.removeTap(onBus: 0)
    audioEngine?.stop()
}
```

### 4. Device Enumeration

```swift
static func availableMicrophones() -> [AudioDevice] {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)

    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &audioDevices)

    // Filter to input devices and get names
    return audioDevices.compactMap { deviceID -> AudioDevice? in
        // Check if device has input channels
        guard hasInputChannels(deviceID) else { return nil }
        let name = getDeviceName(deviceID)
        let isDefault = isDefaultInputDevice(deviceID)
        return AudioDevice(id: deviceID, name: name, isDefault: isDefault)
    }
}
```

## Waveform Visualization

### WaveformLayer in CircularContentView

```swift
// Add to CircularContentView
private var waveformLayer: CAShapeLayer?
private var displayLink: CVDisplayLink?
private var currentAudioLevel: Float = 0
private var wavePhase: CGFloat = 0

func setupWaveform() {
    waveformLayer = CAShapeLayer()
    waveformLayer?.fillColor = nil
    waveformLayer?.strokeColor = NSColor(red: 0, green: 1, blue: 0, alpha: 0.8).cgColor
    waveformLayer?.lineWidth = 2
    layer?.addSublayer(waveformLayer!)
}

func updateAudioLevel(_ level: Float) {
    currentAudioLevel = level
}
```

### Wave Path Generation

```swift
func generateWavePath() -> CGPath {
    let path = CGMutablePath()
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let radius = min(bounds.width, bounds.height) / 2 - 4  // Slightly inside edge

    let waveAmplitude = CGFloat(currentAudioLevel) * 8  // Max 8pt amplitude
    let waveFrequency: CGFloat = 12  // Number of waves around circle

    let points = 360
    for i in 0...points {
        let angle = CGFloat(i) * .pi * 2 / CGFloat(points)

        // Wave offset based on angle and phase
        let wave = sin(angle * waveFrequency + wavePhase) * waveAmplitude
        let r = radius + wave

        let x = center.x + r * cos(angle)
        let y = center.y + r * sin(angle)

        if i == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }

    path.closeSubpath()
    return path
}
```

### Animation Loop

```swift
// Use CADisplayLink or Timer for smooth animation
func startWaveAnimation() {
    let timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
        guard let self = self else { return }

        // Advance wave phase for animation
        self.wavePhase += 0.1

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.waveformLayer?.path = self.generateWavePath()
        CATransaction.commit()
    }
    RunLoop.main.add(timer, forMode: .common)
}
```

## Menu Bar Integration

### Microphone Submenu

```swift
func createMicrophoneSubmenu() -> NSMenu {
    let menu = NSMenu()

    let microphones = AudioManager.availableMicrophones()

    if microphones.isEmpty {
        let noMic = NSMenuItem(title: "No Microphone Available", action: nil, keyEquivalent: "")
        noMic.isEnabled = false
        menu.addItem(noMic)
        return menu
    }

    let currentDevice = audioManager.currentDevice

    for mic in microphones {
        let item = NSMenuItem(
            title: mic.name,
            action: #selector(selectMicrophone(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = mic

        if mic.id == currentDevice?.id {
            item.state = .on
        }

        menu.addItem(item)
    }

    return menu
}
```

### Menu Structure Update

```
┌─────────────────────────┐
│ Hide Window       ⌘H    │
├─────────────────────────┤
│ Camera                 ▸│
│ Microphone             ▸│  ← NEW
│   ├ ✓ MacBook Pro Mic   │
│   ├   USB Microphone    │
│   └   AirPods           │
├─────────────────────────┤
│ Launch at Login         │
├─────────────────────────┤
│ Quit Iris         ⌘Q    │
└─────────────────────────┘
```

## Resource Management

### When to Start/Stop Monitoring

**Start:**
- When window becomes visible
- Only if permission granted

**Stop:**
- When window is hidden
- On app quit

**Integration with CircularWindow:**
```swift
func show() {
    self.orderFrontRegardless()
    cameraManager.startSession()
    audioManager.startMonitoring()  // Add this
}

func hide() {
    self.orderOut(nil)
    cameraManager.stopSession()
    audioManager.stopMonitoring()  // Add this
}
```

## Error Handling

### Custom Error Types
```swift
enum AudioError: Error, LocalizedError {
    case permissionDenied
    case noDeviceAvailable
    case engineStartFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access denied. Enable in System Settings."
        case .noDeviceAvailable:
            return "No microphone device found"
        case .engineStartFailed:
            return "Failed to start audio monitoring"
        }
    }
}
```

### Graceful Degradation
- If microphone permission denied: No visualization, no error shown
- If no microphone: No visualization, menu shows "No Microphone Available"
- Camera continues to work regardless of microphone status

## Testing Checklist

### Permission States
- [ ] First launch - shows permission dialog
- [ ] Permission granted - visualization works
- [ ] Permission denied - no visualization, app still works

### Visual
- [ ] Wave appears around circle edge
- [ ] Wave is green colored
- [ ] Wave amplitude responds to audio level
- [ ] Wave animates smoothly (60fps)
- [ ] Wave stops when window hidden

### Device Selection
- [ ] Menu shows available microphones
- [ ] Checkmark on current microphone
- [ ] Switching microphone works
- [ ] Handles device disconnect

## Implementation Checklist

- [ ] Create AudioManager class
- [ ] Add microphone usage description to Info.plist
- [ ] Implement permission checking
- [ ] Implement audio level monitoring with AVAudioEngine
- [ ] Implement device enumeration
- [ ] Implement device switching
- [ ] Add waveform layer to CircularContentView
- [ ] Implement wave path generation
- [ ] Add animation loop
- [ ] Integrate with CircularWindow show/hide
- [ ] Add microphone submenu to MenuBarController
- [ ] Test with various microphones
- [ ] Verify resource cleanup

## Common Pitfalls

### 1. Audio Tap Threading
❌ **Don't:** Update UI directly in tap callback
✅ **Do:** Dispatch to main thread

### 2. Format Mismatch
❌ **Don't:** Assume fixed audio format
✅ **Do:** Get format from input node

### 3. Resource Leaks
❌ **Don't:** Forget to remove tap
✅ **Do:** Remove tap before stopping engine

### 4. Permission Timing
❌ **Don't:** Start engine without permission
✅ **Do:** Check permission first

## Dependencies
- AVFoundation framework
- CoreAudio framework (for device enumeration)
- AppKit (for menu integration)
- Integrates with CircularWindow, MenuBarController

## Visual Design

### Wave Specifications
- **Color:** Green (#00FF00) with 80% opacity
- **Line Width:** 2 points
- **Position:** 4 points inside the circle edge
- **Frequency:** 12 complete waves around circumference
- **Max Amplitude:** 8 points (at full volume)
- **Animation:** Continuous rotation at ~0.1 radians per frame

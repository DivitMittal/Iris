import Cocoa
import AVFoundation

class CircularContentView: NSView {
    // MARK: - Properties
    private var maskLayer: CAShapeLayer?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Audio Glow Properties
    private var glowGradientLayer: CAGradientLayer?
    private var glowMaskLayer: CAShapeLayer?
    private var glowAnimationTimer: Timer?
    private var currentAudioLevel: Float = 0
    private var smoothedAudioLevel: Float = 0

    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        setupGlowLayer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopGlowAnimation()
    }

    // MARK: - Layer Configuration
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard let layer = self.layer else { return }

        // Background color (visible inside circle)
        layer.backgroundColor = NSColor.black.cgColor

        // Update mask without animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateMask()
        CATransaction.commit()
    }

    override func layout() {
        super.layout()

        // Disable animations during layout
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Update preview layer frame
        if let previewLayer = previewLayer {
            previewLayer.frame = bounds
        }

        // Update circular mask
        updateMask()

        CATransaction.commit()
    }

    func updateMask() {
        guard let layer = self.layer else { return }

        // Create circular mask
        let diameter = min(bounds.width, bounds.height)
        let rect = CGRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )

        // Reuse existing mask layer or create new one
        if maskLayer == nil {
            maskLayer = CAShapeLayer()
        }

        maskLayer?.path = CGPath(ellipseIn: rect, transform: nil)
        layer.mask = maskLayer

        // Update shadow to circular shape
        layer.shadowPath = maskLayer?.path
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: -5)
    }

    // MARK: - Preview Layer Management
    func setPreviewLayer(_ previewLayer: AVCaptureVideoPreviewLayer) {
        // Remove old preview layer if exists
        self.previewLayer?.removeFromSuperlayer()

        // Disable implicit animations on preview layer
        previewLayer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "frame": NSNull(),
            "transform": NSNull()
        ]

        // Configure and add new preview layer
        previewLayer.frame = bounds
        previewLayer.videoGravity = .resizeAspectFill

        if let layer = self.layer {
            layer.insertSublayer(previewLayer, at: 0)
        }

        self.previewLayer = previewLayer

        // Ensure glow is on top
        if let glowGradientLayer = glowGradientLayer {
            layer?.addSublayer(glowGradientLayer)
        }
    }

    // MARK: - Glow Setup
    private func setupGlowLayer() {
        // Create radial gradient layer for inward glow
        glowGradientLayer = CAGradientLayer()
        glowGradientLayer?.type = .radial

        // Gradient from center outward: transparent center -> green edge
        glowGradientLayer?.colors = [
            NSColor.clear.cgColor,
            NSColor.clear.cgColor,
            NSColor(red: 0, green: 1, blue: 0, alpha: 0).cgColor
        ]
        glowGradientLayer?.locations = [0.0, 0.6, 1.0]

        // Radial gradient positioning (center to edge)
        glowGradientLayer?.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowGradientLayer?.endPoint = CGPoint(x: 1.0, y: 1.0)

        glowGradientLayer?.opacity = 0

        // Create circular mask for the gradient
        glowMaskLayer = CAShapeLayer()

        // Disable implicit animations
        glowGradientLayer?.actions = [
            "colors": NSNull(),
            "locations": NSNull(),
            "opacity": NSNull()
        ]
    }

    // MARK: - Audio Level Updates
    func updateAudioLevel(_ level: Float) {
        currentAudioLevel = level
    }

    // MARK: - Glow Animation
    func startWaveAnimation() {
        guard glowAnimationTimer == nil else { return }

        // Add glow layer if not already added
        if let layer = self.layer, glowGradientLayer?.superlayer == nil {
            layer.addSublayer(glowGradientLayer!)
        }

        // Create timer for 60fps animation
        glowAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateGlow()
        }
        RunLoop.main.add(glowAnimationTimer!, forMode: .common)
    }

    func stopWaveAnimation() {
        stopGlowAnimation()
    }

    func stopGlowAnimation() {
        glowAnimationTimer?.invalidate()
        glowAnimationTimer = nil

        // Clear glow
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowGradientLayer?.opacity = 0
        CATransaction.commit()
    }

    private func updateGlow() {
        // Smooth the audio level for buttery animation
        let smoothingFactor: Float = 0.25
        smoothedAudioLevel = smoothedAudioLevel * (1 - smoothingFactor) + currentAudioLevel * smoothingFactor

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Update gradient frame and mask to match circle
        let diameter = min(bounds.width, bounds.height)
        let rect = CGRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )
        glowGradientLayer?.frame = rect

        // Circular mask
        glowMaskLayer?.path = CGPath(ellipseIn: CGRect(origin: .zero, size: rect.size), transform: nil)
        glowMaskLayer?.frame = CGRect(origin: .zero, size: rect.size)
        glowGradientLayer?.mask = glowMaskLayer

        let level = CGFloat(smoothedAudioLevel)

        if smoothedAudioLevel > 0.003 {
            // Show the glow - intensity based on audio level
            glowGradientLayer?.opacity = 1.0

            // Calculate how far inward the glow reaches (max 5% from edge)
            // At low volume: glow only at very edge (~2%)
            // At high volume: glow reaches ~5% inward
            let glowDepth = 0.95 + (1.0 - level) * 0.03  // 0.95 to 0.98 (inner edge of glow)

            // White glow intensity based on volume - max 50% opacity
            let glowAlpha = 0.15 + level * 0.35  // 0.15 to 0.5 alpha

            // Update gradient colors - transparent center, subtle white edge glow
            glowGradientLayer?.colors = [
                NSColor.clear.cgColor,
                NSColor.clear.cgColor,
                NSColor.white.withAlphaComponent(glowAlpha * 0.3).cgColor,
                NSColor.white.withAlphaComponent(glowAlpha).cgColor
            ]

            // Gradient stops - subtle edge glow
            glowGradientLayer?.locations = [
                0.0,
                NSNumber(value: glowDepth - 0.02),
                NSNumber(value: glowDepth),
                1.0
            ]
        } else {
            glowGradientLayer?.opacity = 0
        }

        CATransaction.commit()
    }
}

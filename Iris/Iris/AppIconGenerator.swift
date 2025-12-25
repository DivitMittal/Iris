//
//  AppIconGenerator.swift
//  Iris
//
//  Generates application icons with enhanced Almond Eye design
//

import Cocoa

class AppIconGenerator {

    /// Generates an enhanced Almond Eye app icon at the specified size
    /// - Parameter size: The size of the icon to generate
    /// - Returns: An NSImage with the app icon
    static func generateAppIcon(size: CGSize) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let minDimension = min(size.width, size.height)

            // Scale factors based on size - larger icons get more detail
            let isLargeIcon = minDimension >= 256
            let isMediumIcon = minDimension >= 64 && minDimension < 256
            let isSmallIcon = minDimension < 64

            // Eye dimensions scale with icon size
            let eyeWidth = minDimension * 0.75
            let eyeHeight = minDimension * 0.4
            let irisRadius = minDimension * 0.15
            let pupilRadius = minDimension * 0.075

            // Background circle for better contrast (larger icons only)
            if isLargeIcon {
                let bgRadius = minDimension * 0.48
                let bgCircle = NSBezierPath(
                    ovalIn: NSRect(
                        x: center.x - bgRadius,
                        y: center.y - bgRadius,
                        width: bgRadius * 2,
                        height: bgRadius * 2
                    )
                )

                // Subtle gradient background
                let gradient = NSGradient(colors: [
                    NSColor(white: 0.95, alpha: 1.0),
                    NSColor(white: 0.90, alpha: 1.0)
                ])
                gradient?.draw(in: bgCircle, angle: -90)
            }

            // Draw almond shape using bezier curves
            let almondPath = NSBezierPath()

            // Left and right points
            let leftPoint = NSPoint(x: center.x - eyeWidth / 2, y: center.y)
            let rightPoint = NSPoint(x: center.x + eyeWidth / 2, y: center.y)

            // Control points for top curve
            let topControlLeft = NSPoint(x: center.x - eyeWidth / 4, y: center.y + eyeHeight / 2)
            let topControlRight = NSPoint(x: center.x + eyeWidth / 4, y: center.y + eyeHeight / 2)

            // Control points for bottom curve
            let bottomControlLeft = NSPoint(x: center.x - eyeWidth / 4, y: center.y - eyeHeight / 2)
            let bottomControlRight = NSPoint(x: center.x + eyeWidth / 4, y: center.y - eyeHeight / 2)

            // Draw top half of almond
            almondPath.move(to: leftPoint)
            almondPath.curve(to: rightPoint, controlPoint1: topControlLeft, controlPoint2: topControlRight)

            // Draw bottom half of almond
            almondPath.curve(to: leftPoint, controlPoint1: bottomControlRight, controlPoint2: bottomControlLeft)
            almondPath.close()

            // Stroke width scales with icon size
            let strokeWidth = isSmallIcon ? 1.0 : (isMediumIcon ? 2.0 : 3.0)
            almondPath.lineWidth = strokeWidth

            // For large icons, add subtle shadow
            if isLargeIcon {
                let shadow = NSShadow()
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
                shadow.shadowOffset = NSSize(width: 0, height: -2)
                shadow.shadowBlurRadius = 4
                shadow.set()
            }

            // Draw almond outline
            NSColor.black.setStroke()
            almondPath.stroke()

            // Reset shadow for subsequent drawing
            if isLargeIcon {
                NSShadow().set()
            }

            // Draw iris circle with gradient for larger icons
            let irisRect = NSRect(
                x: center.x - irisRadius,
                y: center.y - irisRadius,
                width: irisRadius * 2,
                height: irisRadius * 2
            )
            let irisCircle = NSBezierPath(ovalIn: irisRect)

            if isLargeIcon {
                // Gradient fill for iris (darker outer, lighter inner)
                let irisGradient = NSGradient(colors: [
                    NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0),
                    NSColor(red: 0.4, green: 0.5, blue: 0.7, alpha: 1.0)
                ])
                irisGradient?.draw(in: irisCircle, angle: -45)

                // Stroke iris circle
                NSColor.black.setStroke()
                irisCircle.lineWidth = strokeWidth * 0.6
                irisCircle.stroke()
            } else if isMediumIcon {
                // Medium icons: solid fill with stroke
                NSColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1.0).setFill()
                irisCircle.fill()
                NSColor.black.setStroke()
                irisCircle.lineWidth = strokeWidth * 0.7
                irisCircle.stroke()
            } else {
                // Small icons: just stroke
                NSColor.black.setStroke()
                irisCircle.lineWidth = strokeWidth * 0.8
                irisCircle.stroke()
            }

            // Draw pupil (filled)
            let pupilCircle = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - pupilRadius,
                    y: center.y - pupilRadius,
                    width: pupilRadius * 2,
                    height: pupilRadius * 2
                )
            )
            NSColor.black.setFill()
            pupilCircle.fill()

            // Add highlight reflection for larger icons
            if isLargeIcon {
                NSColor.white.setFill()

                // Main highlight (upper right)
                let highlightRadius = pupilRadius * 0.4
                let highlightOffset = pupilRadius * 0.3
                let highlightCenter = NSPoint(
                    x: center.x + highlightOffset,
                    y: center.y + highlightOffset
                )
                let highlightCircle = NSBezierPath(
                    ovalIn: NSRect(
                        x: highlightCenter.x - highlightRadius,
                        y: highlightCenter.y - highlightRadius,
                        width: highlightRadius * 2,
                        height: highlightRadius * 2
                    )
                )
                highlightCircle.fill()

                // Secondary smaller highlight
                let smallHighlightRadius = pupilRadius * 0.2
                let smallHighlightCenter = NSPoint(
                    x: center.x - highlightOffset * 0.5,
                    y: center.y - highlightOffset * 0.5
                )
                let smallHighlightCircle = NSBezierPath(
                    ovalIn: NSRect(
                        x: smallHighlightCenter.x - smallHighlightRadius,
                        y: smallHighlightCenter.y - smallHighlightRadius,
                        width: smallHighlightRadius * 2,
                        height: smallHighlightRadius * 2
                    )
                )
                smallHighlightCircle.fill()
            } else if isMediumIcon {
                // Single highlight for medium icons
                NSColor.white.setFill()
                let highlightRadius = pupilRadius * 0.35
                let highlightOffset = pupilRadius * 0.25
                let highlightCenter = NSPoint(
                    x: center.x + highlightOffset,
                    y: center.y + highlightOffset
                )
                let highlightCircle = NSBezierPath(
                    ovalIn: NSRect(
                        x: highlightCenter.x - highlightRadius,
                        y: highlightCenter.y - highlightRadius,
                        width: highlightRadius * 2,
                        height: highlightRadius * 2
                    )
                )
                highlightCircle.fill()
            }

            return true
        }
        return image
    }

    /// Generates an app icon and saves it as a PNG file
    /// - Parameters:
    ///   - size: The size of the icon to generate
    ///   - outputPath: The file path where the PNG should be saved
    static func generateAndSaveIcon(size: CGSize, outputPath: String) throws {
        let image = generateAppIcon(size: size)

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            throw NSError(domain: "AppIconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap representation"])
        }

        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "AppIconGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
        }

        let url = URL(fileURLWithPath: outputPath)
        try pngData.write(to: url)
    }
}

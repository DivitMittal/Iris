#!/bin/bash

# Generate application icons for Iris.app
# Creates all required icon sizes based on Contents.json

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/Iris"
ICON_DIR="$PROJECT_DIR/Iris/Assets.xcassets/AppIcon.appiconset"
CONTENTS_JSON="$ICON_DIR/Contents.json"

echo "🎨 Generating application icons..."

# Check if icon directory exists
if [ ! -d "$ICON_DIR" ]; then
    echo "❌ Error: Icon directory not found: $ICON_DIR"
    exit 1
fi

# Create a temporary Swift script to generate icons
TEMP_SCRIPT=$(mktemp /tmp/generate_icons.XXXXXX.swift)
cat > "$TEMP_SCRIPT" << 'SWIFT_SCRIPT'
import Foundation
import Cocoa

let iconDir = CommandLine.arguments[1]

// Icon sizes to generate (size in points, scale factor, filename)
let iconSizes: [(size: CGFloat, scale: Int, filename: String, jsonSize: String)] = [
    (16, 1, "icon_16x16.png", "16x16"),
    (32, 2, "icon_16x16@2x.png", "16x16"),
    (32, 1, "icon_32x32.png", "32x32"),
    (64, 2, "icon_32x32@2x.png", "32x32"),
    (128, 1, "icon_128x128.png", "128x128"),
    (256, 2, "icon_128x128@2x.png", "128x128"),
    (256, 1, "icon_256x256.png", "256x256"),
    (512, 2, "icon_256x256@2x.png", "256x256"),
    (512, 1, "icon_512x512.png", "512x512"),
    (1024, 2, "icon_512x512@2x.png", "512x512"),
]

// Generate app icon (inline version of AppIconGenerator)
func generateAppIcon(size: CGSize) -> NSImage {
    let image = NSImage(size: size, flipped: false) { rect in
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let minDimension = min(size.width, size.height)

        let isLargeIcon = minDimension >= 256
        let isMediumIcon = minDimension >= 64 && minDimension < 256
        let isSmallIcon = minDimension < 64

        let eyeWidth = minDimension * 0.75
        let eyeHeight = minDimension * 0.4
        let irisRadius = minDimension * 0.15
        let pupilRadius = minDimension * 0.075

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
            let gradient = NSGradient(colors: [
                NSColor(white: 0.95, alpha: 1.0),
                NSColor(white: 0.90, alpha: 1.0)
            ])
            gradient?.draw(in: bgCircle, angle: -90)
        }

        let almondPath = NSBezierPath()
        let leftPoint = NSPoint(x: center.x - eyeWidth / 2, y: center.y)
        let rightPoint = NSPoint(x: center.x + eyeWidth / 2, y: center.y)
        let topControlLeft = NSPoint(x: center.x - eyeWidth / 4, y: center.y + eyeHeight / 2)
        let topControlRight = NSPoint(x: center.x + eyeWidth / 4, y: center.y + eyeHeight / 2)
        let bottomControlLeft = NSPoint(x: center.x - eyeWidth / 4, y: center.y - eyeHeight / 2)
        let bottomControlRight = NSPoint(x: center.x + eyeWidth / 4, y: center.y - eyeHeight / 2)

        almondPath.move(to: leftPoint)
        almondPath.curve(to: rightPoint, controlPoint1: topControlLeft, controlPoint2: topControlRight)
        almondPath.curve(to: leftPoint, controlPoint1: bottomControlRight, controlPoint2: bottomControlLeft)
        almondPath.close()

        let strokeWidth = isSmallIcon ? 1.0 : (isMediumIcon ? 2.0 : 3.0)
        almondPath.lineWidth = strokeWidth

        if isLargeIcon {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.shadowBlurRadius = 4
            shadow.set()
        }

        NSColor.black.setStroke()
        almondPath.stroke()

        if isLargeIcon {
            NSShadow().set()
        }

        let irisRect = NSRect(
            x: center.x - irisRadius,
            y: center.y - irisRadius,
            width: irisRadius * 2,
            height: irisRadius * 2
        )
        let irisCircle = NSBezierPath(ovalIn: irisRect)

        if isLargeIcon {
            let irisGradient = NSGradient(colors: [
                NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0),
                NSColor(red: 0.4, green: 0.5, blue: 0.7, alpha: 1.0)
            ])
            irisGradient?.draw(in: irisCircle, angle: -45)
            NSColor.black.setStroke()
            irisCircle.lineWidth = strokeWidth * 0.6
            irisCircle.stroke()
        } else if isMediumIcon {
            NSColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1.0).setFill()
            irisCircle.fill()
            NSColor.black.setStroke()
            irisCircle.lineWidth = strokeWidth * 0.7
            irisCircle.stroke()
        } else {
            NSColor.black.setStroke()
            irisCircle.lineWidth = strokeWidth * 0.8
            irisCircle.stroke()
        }

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

        if isLargeIcon {
            NSColor.white.setFill()
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

// Generate all icons and collect JSON entries
var jsonEntries: [[String: String]] = []

for iconSpec in iconSizes {
    let size = CGSize(width: iconSpec.size, height: iconSpec.size)
    let image = generateAppIcon(size: size)

    guard let tiffData = image.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData) else {
        print("Error: Failed to create bitmap for \(iconSpec.filename)")
        exit(1)
    }

    guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
        print("Error: Failed to create PNG for \(iconSpec.filename)")
        exit(1)
    }

    let outputPath = (iconDir as NSString).appendingPathComponent(iconSpec.filename)
    let url = URL(fileURLWithPath: outputPath)

    do {
        try pngData.write(to: url)
        print("✅ Generated \(iconSpec.filename)")

        // Create JSON entry
        let scaleStr = iconSpec.scale == 1 ? "1x" : "2x"
        jsonEntries.append([
            "filename": iconSpec.filename,
            "idiom": "mac",
            "scale": scaleStr,
            "size": iconSpec.jsonSize
        ])
    } catch {
        print("Error: Failed to write \(iconSpec.filename): \(error)")
        exit(1)
    }
}

// Create JSON structure
let jsonDict: [String: Any] = [
    "images": jsonEntries,
    "info": [
        "author": "xcode",
        "version": 1
    ]
]

// Write JSON
let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: [.prettyPrinted, .sortedKeys])
let jsonString = String(data: jsonData, encoding: .utf8)!
let jsonURL = URL(fileURLWithPath: (iconDir as NSString).appendingPathComponent("Contents.json"))
try jsonString.write(to: jsonURL, atomically: true, encoding: .utf8)

print("✅ Updated Contents.json")
print("✅ All icons generated successfully!")
SWIFT_SCRIPT

# Run the Swift script
swift "$TEMP_SCRIPT" "$ICON_DIR"

# Clean up
rm "$TEMP_SCRIPT"

echo "✅ Icon generation complete!"

# 07 - Menu Bar Icon Design

## Overview

The menu bar icon is the primary visual identity of Iris in the macOS menu bar. It should be instantly recognizable, work well at small sizes (16-18pt), and properly support both light and dark modes through template image rendering.

## Design Requirements

1. **Size**: 16x16 or 18x18 points (menu bar standard)
2. **Template Image**: Must work as a template image (single color, macOS handles light/dark)
3. **Recognizable**: Should evoke "eye" or "iris" concept
4. **Distinctive**: Should stand out from other menu bar icons
5. **Simple**: Must remain clear at small sizes

## Icon Options

### Option A: SF Symbol "eye.circle"

Uses Apple's built-in SF Symbol for an eye inside a circle.

```
Visual:
  ┌─────────┐
  │  ◉──◉   │
  └─────────┘
```

**Implementation**: Use `NSImage(systemSymbolName: "eye.circle")`

**Pros**:
- Native macOS look
- Automatic dark/light mode support
- No custom drawing code
- Consistent with system aesthetics

**Cons**:
- Generic, not unique to Iris
- No radiating iris lines
- Less distinctive

---

### Option B: Neural Web

Custom-drawn icon featuring a central pupil with randomized curved neural branches emanating outward, creating an organic neural network aesthetic. No outer circle boundary.

```
Visual:
    •     •
     ╲   ╱
   •──●──•
      │╲
      • •
```

**Implementation**: Custom `NSBezierPath` drawing:
1. Define randomized branch data (angles, lengths, curves)
2. Draw 8 curved neural branches from pupil outward with varying lengths
3. Draw nodes (small filled circles) at branch endpoints
4. Draw secondary branches on select main branches
5. Draw central pupil (filled circle)
6. Draw light reflection highlight on pupil

**Pros**:
- Unique and distinctive
- Organic, asymmetric pattern feels natural
- No rigid outer boundary - feels more dynamic
- Neural/tech aesthetic
- Nodes add visual interest

**Cons**:
- Requires custom drawing code
- More complex implementation
- Abstract - may not immediately read as "eye"

---

### Option C: Concentric Rings

Three concentric elements: outer circle (eye), middle ring (iris), inner dot (pupil).

```
Visual:
    ┌───────┐
    │ ┌───┐ │
    │ │ ● │ │
    │ └───┘ │
    └───────┘
```

**Implementation**: Custom `NSBezierPath` drawing:
1. Draw outer circle (stroke)
2. Draw middle circle (stroke, smaller)
3. Draw inner filled circle (pupil)

**Pros**:
- Clean and minimal
- Simple to implement
- Works well at small sizes

**Cons**:
- Could be mistaken for a target/bullseye
- Less distinctive
- Doesn't clearly read as "eye"

---

### Option D: Stylized Almond Eye

Almond/leaf-shaped eye outline with inner circle for iris/pupil.

```
Visual:
     ╱──●──╲
    ◟      ◞
```

**Implementation**: Custom `NSBezierPath` drawing:
1. Draw almond shape using bezier curves (two arcs meeting at points)
2. Draw inner circle (iris)
3. Optionally draw smaller inner dot (pupil)

**Pros**:
- Clearly recognizable as an eye
- Distinctive shape
- Good visual metaphor

**Cons**:
- More complex bezier curves
- May be harder to see details at small size
- Horizontal orientation might not fit well in menu bar

---

## Implementation

All options will be implemented in `MenuBarController.swift` with a selection mechanism to switch between them for comparison.

### Icon Drawing Helper

```swift
enum MenuBarIconStyle: Int {
    case sfSymbolEye = 0      // Option A: SF Symbol
    case neuralWeb = 1        // Option B: Neural Web
    case concentricRings = 2  // Option C: Concentric Rings
    case almondEye = 3        // Option D: Almond Eye (default)
}

func createMenuBarIcon(style: MenuBarIconStyle, size: CGSize) -> NSImage
```

### Testing

A preference or menu item will allow cycling through all options to compare them in the actual menu bar context.

## Recommendation

**Option D (Almond Eye)** is the current default because:
1. Clearly recognizable as an eye
2. Classic, universally understood eye shape
3. Simple and clean at small sizes
4. Distinctive almond silhouette

**Option B (Neural Web)** is an alternative for a more tech/neural aesthetic.

## Decision

**Almond Eye** selected as default. Neural Web available as alternative option in menu.

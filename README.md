# Niri for macOS

A native macOS window manager with smooth physics-based scrolling tiling.

## Status: Phase 2 - Scrolling & Animations

**Current Features:**
- Window tracking via Accessibility API
- Horizontal tiling layout with smooth scrolling
- **Spring physics animations** for natural motion
- **Velocity-based gesture tracking**
- **Touchpad swipe gestures** with momentum
- **Snap-to-column behavior**
- Keyboard navigation (Cmd+Option+H/J/K/L)
- 120Hz ProMotion support via CVDisplayLink
- Automatic window management
- Multi-column support

**In Development:**
- Multi-monitor support (Phase 3)
- Workspace management (Phase 3)
- Visual feedback and borders (Phase 4)

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permissions

## Building

```bash
cd NiriMacOS
swift build -c release
```

## Running

```bash
swift run
```

On first launch, grant Accessibility permissions when prompted.

## Controls

### Keyboard Shortcuts

- `Cmd+Option+H` - Focus window left
- `Cmd+Option+L` - Focus window right
- `Cmd+Option+K` - Focus window up (within column)
- `Cmd+Option+J` - Focus window down (within column)

### Touchpad Gestures

- **Two-finger horizontal swipe** - Scroll through window columns
  - Smooth physics-based scrolling
  - Velocity tracking with momentum
  - Automatic snap to nearest column
  - Works on both trackpad and Magic Mouse

## Algorithms

### Spring Physics Animation

The animation system uses a critically-damped spring model for smooth, natural motion. Key properties:

- **Damping Ratio**: Controls how quickly oscillations settle (critically damped = 1.0 for no overshoot)
- **Natural Frequency**: Determines animation speed while maintaining physical plausibility
- **Velocity Continuity**: Animations can be interrupted and seamlessly transition to new targets

The spring equation `x'' + 2ζωx' + ω²x = 0` is solved analytically for precise frame-by-frame positions.

### Gesture Tracking

The gesture system implements velocity estimation with several techniques:

- **Exponential smoothing**: Filters noisy input while preserving responsiveness
- **Directional locking**: Prevents diagonal drift during intentional horizontal/vertical swipes
- **Momentum calculation**: Converts final gesture velocity into animation parameters

### Layout Engine

The scrolling layout uses a column-based approach:

- Windows are organized into columns that tile horizontally
- Each column can contain multiple vertically-stacked windows
- The view scrolls horizontally, with one column designated as "active"
- Snap points are calculated based on column positions and widths
- Smooth interpolation handles the transition between discrete column positions

## Implementation Phases

### Phase 1: Foundation
- Window tracking via Accessibility API
- Basic tiling layout
- Keyboard shortcuts

### Phase 2: Scrolling & Animations
- Spring physics animations
- Velocity-based gesture tracking
- 120Hz smooth scrolling
- Snap-to-column behavior

### Phase 3: Multi-Monitor & Workspaces
- Per-monitor workspaces
- Vertical workspace switching
- Display hotplug support

### Phase 4: Polish & Advanced Features
- Visual feedback (borders, overlays)
- Configuration system
- Window rules
- Performance optimization

## License

GPL-3.0-or-later

## Inspiration

This project was inspired by [niri](https://github.com/YaLTeR/niri), a scrollable-tiling Wayland compositor for GNOME Linux.

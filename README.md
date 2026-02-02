# Niri for macOS

A native macOS window manager inspired by [niri](https://github.com/YaLTeR/niri), bringing smooth physics-based scrolling tiling to macOS.

## Status: Phase 1 - Foundation

**Current Features:**
- ✅ Window tracking via Accessibility API
- ✅ Basic horizontal tiling layout
- ✅ Keyboard navigation (Cmd+Option+H/J/K/L)
- ✅ Automatic window management
- ✅ Multi-column support

**In Development:**
- 🚧 Spring physics animations (Phase 2)
- 🚧 Smooth scrolling with velocity tracking (Phase 2)
- 🚧 Multi-monitor support (Phase 3)
- 🚧 Workspace management (Phase 3)

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

## Keyboard Shortcuts

- `Cmd+Option+H` - Focus window left
- `Cmd+Option+L` - Focus window right
- `Cmd+Option+K` - Focus window up (within column)
- `Cmd+Option+J` - Focus window down (within column)

## Architecture

This is a direct port of niri's layout algorithms to macOS:

- **Layout Engine**: Ported from `niri/src/layout/scrolling.rs` (5,601 lines)
- **Spring Physics**: Will port from `niri/src/animation/spring.rs` (210 lines)
- **Gesture Tracking**: Will port from `niri/src/input/swipe_tracker.rs` (88 lines)

## Implementation Phases

### Phase 1: Foundation ✅ (Current)
- Window tracking via Accessibility API
- Basic tiling layout
- Keyboard shortcuts

### Phase 2: Scrolling & Animations (Next)
- Spring physics port
- Velocity-based gestures
- 120Hz smooth scrolling

### Phase 3: Multi-Monitor & Workspaces
- Per-monitor workspaces
- Vertical workspace switching
- Display hotplug support

### Phase 4: Polish & Advanced Features
- Visual feedback (borders, overlays)
- Configuration system (KDL format)
- Window rules
- Performance optimization

## License

GPL-3.0-or-later (matching niri's license)

## Credits

Inspired by and porting algorithms from [niri](https://github.com/YaLTeR/niri) by YaLTeR.

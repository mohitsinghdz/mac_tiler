# NiriMacOS Controls Guide

## Current Controls (Phase 2)

### 🖱️ Focus Navigation (Keyboard)

Move **focus** between windows without moving them:

- `Cmd+Option+H` - Focus window to the **left**
- `Cmd+Option+L` - Focus window to the **right**
- `Cmd+Option+K` - Focus window **up** (within same column)
- `Cmd+Option+J` - Focus window **down** (within same column)

> **Note:** These only change which window is focused, they don't move windows.

---

### 🖱️ Touchpad Scrolling (NEW in Phase 2)

**Two-finger horizontal swipe** to scroll through columns:

- **Swipe Left** → Scroll right (see windows to the right)
- **Swipe Right** → Scroll left (see windows to the left)
- **Fast swipe** → Momentum scrolling with snap-to-column
- **Slow swipe** → Gentle scroll

**How it works:**
1. Place two fingers on trackpad
2. Swipe horizontally (left or right)
3. Release and it will snap to nearest column boundary
4. Physics-based animation with spring damping

---

### 🚫 NOT YET IMPLEMENTED

These controls are planned but not yet added:

- ❌ Moving windows between columns (Phase 3)
- ❌ Resizing windows (Phase 3)
- ❌ Swapping windows (Phase 3)
- ❌ Creating/closing columns (Phase 3)
- ❌ Workspace switching (Phase 3)
- ❌ Floating window toggle (Phase 4)

---

## Debugging Scrolling Issues

If trackpad swipes aren't working, check:

### 1. Enable Debug Logging

The app should print:
```
Gesture began (touchpad: true)
Gesture ended
```

If you don't see these, gestures aren't being detected.

### 2. Check Accessibility Permissions

System Settings → Privacy & Security → Accessibility → NiriMacOS ✓

### 3. Check Window Count

You need **at least 2 columns** (2+ windows) to see scrolling.

### 4. Manual Test Commands

We'll add these keyboard commands for testing:
- `Cmd+Option+[` - Scroll view left
- `Cmd+Option+]` - Scroll view right

---

## Coming in Phase 3

### Window Movement
- `Cmd+Shift+H` - Move window to left column
- `Cmd+Shift+L` - Move window to right column
- `Cmd+Shift+M` - Move window to monitor

### Workspace Control
- Three-finger swipe up/down - Switch workspace
- `Ctrl+1-9` - Jump to workspace

### Column Operations
- `Cmd+Option+{` - Consume window from right (slurp)
- `Cmd+Option+}` - Expel window to right (barf)

---

## Current Limitations

1. **No window movement yet** - Can only change focus
2. **No manual column creation** - Columns auto-created when adding windows
3. **No resize controls** - Windows auto-sized within columns
4. **Single monitor only** - Multi-monitor in Phase 3
5. **No workspaces yet** - Single workspace per monitor

---

## Testing Scrolling Right Now

```bash
# Run the app
.build/release/NiriMacOS

# Open 5-6 windows
# - Safari: Cmd+Space → "Safari" → Enter
# - Terminal: Cmd+Space → "Terminal" → Enter
# - TextEdit: Cmd+Space → "TextEdit" → Enter
# etc.

# Try touchpad:
# - Two fingers on trackpad
# - Swipe left (should scroll right through columns)
# - Swipe right (should scroll left)
```

If this doesn't work, we'll add debug output to see what's happening!

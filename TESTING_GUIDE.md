# Testing Guide - Debugging Scrolling

## Current Controls Summary

### ✅ What Works Now

**Focus Navigation (Keyboard):**
- `Cmd+Option+H` - Focus left column
- `Cmd+Option+L` - Focus right column
- `Cmd+Option+K` - Focus up in column
- `Cmd+Option+J` - Focus down in column

**Touchpad Scrolling (NEW - Testing):**
- Two-finger horizontal swipe should scroll through columns

### ❌ What Doesn't Work Yet

- Moving windows between columns (no shortcuts implemented yet)
- Resizing windows
- Creating/destroying columns manually
- Multi-monitor
- Workspaces

---

## Step-by-Step Testing

### 1. Build and Run with Debug Output

```bash
cd /Users/mohitsingh/Work/niri/MacTiler

# Build
swift build -c release

# Run (you'll see debug output in terminal)
.build/release/MacTiler
```

Keep the terminal visible to see debug output!

---

### 2. Set Up Test Windows

Open **5-6 windows** so you have multiple columns:

```bash
# Quick way to open test windows:
open -a Safari
open -a Terminal
open -a TextEdit
open -a Calculator
open -a Notes
```

**You should see in terminal:**
```
Added window: Safari (Safari)
Added window: Terminal (Terminal)
Added window: TextEdit (TextEdit)
...
```

---

### 3. Test Touchpad Scrolling

**Place two fingers on trackpad and swipe LEFT (to scroll right):**

**Expected terminal output:**
```
📱 Scroll: deltaX=12.5, phase=1, touchpad=true
✅ Gesture began (touchpad: true)
🎯 ScrollingSpace: Gesture began at offset 0.0

📱 Scroll: deltaX=25.0, phase=2, touchpad=true
   → ViewOffset: 25.0
📍 Gesture update: delta=25.0 → normalized=-12.5 → viewPos=12.5

📱 Scroll: deltaX=40.0, phase=2, touchpad=true
   → ViewOffset: 65.0
📍 Gesture update: delta=40.0 → normalized=-20.0 → viewPos=32.5

... (more updates as you swipe)

📱 Scroll: deltaX=0.0, phase=4, touchpad=true
✅ Gesture ended
🎯 Snap calculation:
   Current: 100.0
   Velocity: 50.0
   Projected: 150.0
   Snap points: [0.0, 400.0, 800.0]
   → Target: 0.0 or 400.0 (nearest)
```

---

### 4. What You Should See

**If scrolling WORKS:**
- Windows slide horizontally as you swipe
- Smooth animation
- Snaps to column boundaries when you release
- Debug output shows position changes

**If scrolling DOESN'T WORK:**
- You'll see gesture events in terminal
- But windows don't move
- This tells us where the problem is!

---

### 5. Common Issues

#### Issue: No gesture output at all

**Terminal shows:** Nothing when you swipe

**Cause:** Gesture monitoring not starting

**Fix:** Check that Accessibility permission is granted

---

#### Issue: Gesture detected but windows don't move

**Terminal shows:**
```
✅ Gesture began
📍 Gesture update: delta=25.0 → normalized=-12.5 → viewPos=12.5
```

But windows stay in place.

**Cause:** Layout not being applied each frame

**Debug:** Check if you see:
```
🎨 applyLayout: viewOffset=12.5, columns=5
```

If NOT, the display link isn't calling applyLayout() correctly.

---

#### Issue: Only vertical scroll works

**Terminal shows:** Nothing for horizontal swipes

**Cause:** macOS is interpreting as vertical scroll

**Fix:** Try swiping more horizontally (not at an angle)

---

#### Issue: Windows jump instead of smooth scroll

**Cause:** Display link not running at high frame rate

**Fix:** Check CVDisplayLink is started (we'll verify in output)

---

## Debugging Commands

### Check Current State

Add these keyboard shortcuts for manual testing:

**Cmd+Option+D** - Dump current state (to be added)
- Print number of columns
- Print view offset
- Print window count

**Cmd+Option+[** - Manual scroll left (to be added)
**Cmd+Option+]** - Manual scroll right (to be added)

---

## What to Report

When testing, please share:

1. **What you did:**
   - "Two-finger swipe left"

2. **Terminal output:**
   - Copy/paste the debug messages

3. **What you saw:**
   - "Nothing moved"
   - "Windows jumped"
   - "Smooth scrolling worked!"

4. **Number of windows:**
   - "5 windows across 5 columns"

---

## Quick Test Checklist

- [ ] App starts without errors
- [ ] Windows are automatically tiled
- [ ] Terminal shows "Added window" messages
- [ ] Keyboard focus navigation works (H/J/K/L)
- [ ] Two-finger swipe shows "📱 Scroll" in terminal
- [ ] Swipe shows "✅ Gesture began"
- [ ] Swipe shows position updates
- [ ] Windows move during swipe
- [ ] Windows snap to column on release

---

## Next Steps

Based on what we see in the debug output, we can:

1. Fix gesture detection if needed
2. Fix layout application if needed
3. Tune scrolling parameters
4. Add manual scroll shortcuts for testing
5. Proceed to Phase 3 once scrolling works!

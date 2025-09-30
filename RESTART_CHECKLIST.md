# 🔄 NotedCore Restart Checklist

## ⚡ Quick Start After Reboot

### 1. Open Terminal:
```bash
cd /Users/jamesalford/Documents/NotedCore
open NotedCore.xcodeproj
```

### 2. Fix Permissions (CRITICAL):
```bash
# Reset simulator permissions
xcrun simctl privacy booted reset all com.jamesalford.NotedCore

# Grant microphone
xcrun simctl privacy booted grant microphone com.jamesalford.NotedCore
```

### 3. Check macOS Permissions:
- **System Settings → Privacy & Security → Microphone**
- ✅ Enable for: Xcode
- ✅ Enable for: Simulator

### 4. Launch App:
```bash
# Quick launch script
./launch_and_test.sh
```

OR manually in Xcode:
- Select "iPhone 15" simulator
- Press ⌘R to run

### 5. Test Immediately:
1. Tap blue microphone button
2. Check console for: `🚀 SimpleWhisperService starting...`
3. Speak clearly
4. Look for: `🎤 Processing audio buffer`

---

## 🔍 If Transcription Not Working:

### Check #1: Is WhisperKit Loading?
**Console should show:**
```
🚀 SimpleWhisperService starting...
📥 Loading WhisperKit...
✅ WhisperKit loaded successfully!
```

**If not:** WhisperKit failed to load. Check internet, wait for model download.

### Check #2: Is Audio Being Captured?
**Console should show (repeatedly):**
```
🎤 Processing audio buffer with 512 frames
🔊 Audio detected! Max amplitude: 0.XXX
```

**If not:** Audio engine not running. Reset simulator.

### Check #3: Is WhisperKit Processing?
**Console should show:**
```
📥 SimpleWhisperService.processAudio called with XXX samples
✅ WhisperKit is ready, processing audio...
✅ Transcribed: [your words]
```

**If not:** WhisperKit not processing. Check model loaded.

---

## 🛠️ Common Fixes:

### Fix 1: Reset Everything
```bash
# Kill simulator
xcrun simctl shutdown booted

# Erase simulator
xcrun simctl erase "iPhone 15"

# Boot fresh
xcrun simctl boot "iPhone 15"

# Launch app
./launch_and_test.sh
```

### Fix 2: Clean Build
- Xcode: Product → Clean Build Folder (⇧⌘K)
- Build again (⌘B)
- Run (⌘R)

### Fix 3: Check Audio Input
- System Settings → Sound → Input
- Select correct microphone
- Speak and verify levels

---

## 📊 What Success Looks Like:

1. **App Launch:**
   - UI appears
   - No crash
   - Status shows "WhisperKit ready"

2. **Start Recording:**
   - Tap mic button
   - See "Recording..." status
   - Mic button turns red

3. **While Speaking:**
   - Console shows audio processing
   - Text appears in transcription field
   - Updates in real-time

4. **Transcription Quality:**
   - Words appear as you speak
   - May correct itself
   - Medical terms recognized

---

## 🚨 REMEMBER:
**Transcription WAS working perfectly earlier. If it's not working after restart, it's likely a permission or initialization issue, NOT a code problem.**

---

## 📱 Test Commands:
```bash
# Check if app is running
xcrun simctl list | grep Booted

# Check app process
xcrun simctl spawn booted launchctl list | grep NotedCore

# Force terminate if stuck
xcrun simctl terminate booted com.jamesalford.NotedCore

# Relaunch
xcrun simctl launch booted com.jamesalford.NotedCore
```

---

## 💾 Key Files to Check:
1. **AudioCaptureService.swift** - Line 342-357 has audio detection logging
2. **SimpleWhisperService.swift** - Line 64-72 has WhisperKit ready check
3. **ProductionWhisperService.swift** - Line 170-180 has audio reception logging
4. **ContentView.swift** - Line 218-240 has recording start logic

---

## ✅ When It's Working:
- Live transcription appears as you speak
- Console shows continuous audio processing
- Text updates in real-time
- Just like it was before!
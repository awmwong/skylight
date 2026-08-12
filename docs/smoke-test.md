# Skylight Smoke Test Checklist

Manual verification of the app's success criteria. Run this after
each change that touches sharing, capture, or the virtual display. Fill in
Pass/Fail and notes as you go.

Verified OS: macOS 26.5 (arm64).

Before you start:

```sh
xcodegen generate
xcodebuild -project Skylight.xcodeproj -scheme Skylight -configuration Debug \
  -derivedDataPath build -destination 'platform=macOS' build
open build/Build/Products/Debug/Skylight.app
```

Or `scripts/run.sh`.

Record results here:

| # | Check | Result |
|---|-------|--------|
| 1 | Region selection | [ ] Pass  [ ] Fail |
| 2 | Virtual display appears, live, ≥30 fps | [ ] Pass  [ ] Fail |
| 3a | Shareable in QuickTime | [ ] Pass  [ ] Fail |
| 3b | Shareable in Zoom | [ ] Pass  [ ] Fail |
| 3c | Shareable in Google Meet (Chrome) | [ ] Pass  [ ] Fail |
| 4 | Fixed viewport + last-viewport recall | [ ] Pass  [ ] Fail |
| 5 | Presets save/recall/persist | [ ] Pass  [ ] Fail |
| 6 | Global hotkey toggle | [ ] Pass  [ ] Fail |
| 7 | Cursor include/exclude | [ ] Pass  [ ] Fail |
| 8 | No phantom display on stop/quit | [ ] Pass  [ ] Fail |
| 9 | Test suite + lint clean | [ ] Pass  [ ] Fail |
| 10 | First-run permission prompt flow | [ ] Pass  [ ] Fail |

---

## 1. Region selection

**Setup:** Skylight is running; menu bar shows the Skylight icon; sharing is
idle.

**Steps:**

1. Click the Skylight menu bar icon → **Start Sharing…**.
2. Confirm a dashed border overlay appears on the display under your cursor.
3. Drag inside the border to move it. Drag a corner handle to resize it.
   Drag an edge handle to resize on one axis only.
4. Try to resize below the minimum size; confirm it stops shrinking rather
   than collapsing to zero.
5. Press **Esc**. Confirm the overlay closes and nothing starts sharing.
6. Repeat step 1, adjust the border, then press **Return** (or click the
   confirm control) to accept.

**Expected result:** The border overlay only appears on the display under the
cursor. Drag/resize track the mouse smoothly with no jitter. Esc cancels back
to idle. Confirming starts sharing (the menu bar item changes to "Stop
Sharing").

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

---

## 2. Virtual display appears, live, HiDPI-correct

**Setup:** Continue from a confirmed region (check 1), or start sharing any
region.

**Steps:**

1. Open **System Settings → Displays**.
2. Confirm a display named **"Skylight Display"** is listed.
3. Note the selected region's size in points on the source display (from the
   selection overlay) and the source display's Looking Glass/backing scale
   (2x on a Retina display, 1x on an external non-Retina display).
4. Compute expected virtual-display pixel size = region size in points ×
   backing scale. Compare against the resolution System Settings reports for
   "Skylight Display" (click the display, check "Resolution").
5. Put some moving content in the selected region (a video, a scrolling
   terminal, a clock).
6. Open **QuickTime Player → File → New Screen Recording**, pick "Skylight
   Display" as the source in the recording options popover, and watch the
   live preview thumbnail without recording (or start/stop a few seconds of
   recording and play it back).

**Expected result:** "Skylight Display" appears in System Settings within a
few seconds of starting to share. Its pixel resolution matches region-size ×
backing-scale. The preview/recording shows the live region content updating
smoothly (no stutter you can count below ~30 fps by eye) with no
recursive "hall of mirrors" image (the virtual display's own output must
never appear inside the captured region).

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

---

## 3. Shareable in real conferencing / recording apps

Run all three. At least two must pass; record all for coverage.

### 3a. QuickTime Player

**Steps:**

1. Start sharing a region with distinct content (e.g., a browser tab with
   text).
2. **QuickTime Player → File → New Screen Recording.** (Not "New Movie
   Recording" — that records a camera, not a screen.)
3. In the recording options popover, open the screen/display picker and
   select **"Skylight Display."**
4. Record 5-10 seconds, stop, and play back.

**Expected result:** The recording shows only the selected region's content,
filling the frame, matching what was on screen live.

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

### 3b. Zoom

**Steps:**

1. Start sharing a region.
2. In a Zoom meeting, click **Share Screen**.
3. In the share picker, find **"Skylight Display"** alongside your physical
   displays and windows.
4. Share it. From a second device (or ask another participant), confirm what
   they see matches only the selected region.

**Expected result:** "Skylight Display" is selectable as a screen in Zoom's
share picker and shows only the region's content to viewers.

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

### 3c. Google Meet (Chrome)

**Steps:**

1. Start sharing a region.
2. Join a Google Meet call in Chrome. Click **Present now → A window** or
   **A tab**... use **Entire screen** to find "Skylight Display" as a
   screen option (Meet lists it under screens, not windows/tabs).
3. Present it. Confirm on a second device/participant that only the region
   is visible.

**Expected result:** "Skylight Display" is selectable in Chrome's
`getDisplayMedia` screen picker for Meet and shows only the region.

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

---

## 4. Fixed viewport and last-viewport recall

**Setup:** Sharing is active (any app from check 3, or just QuickTime
preview).

**Steps:**

1. Confirm the selection overlay is gone: no yellow border on screen, and
   every window under the old selection is clickable as normal.
2. Confirm the shared output keeps showing the confirmed region while you
   work in other windows.
3. Stop sharing from the menu bar icon. Select "Start Sharing…" again.
4. Confirm the selection opens preselected at the viewport you just shared.
5. Resize the selection to a different aspect ratio and start the share.
6. Confirm the virtual display matches the new size exactly (no letterbox).

**Expected result:** Once a share starts, nothing stays on screen and no
input is blocked. The viewport is fixed for the whole share. The next
selection starts from the last shared viewport, also after an app relaunch.

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

---

## 5. Presets: save, recall, persist across relaunch

**Steps:**

1. Select and confirm a region (or start a share with one).
2. From the menu bar, save the current region as a preset with a name (e.g.,
   "left half").
3. Stop sharing. Reopen the menu bar; confirm the preset appears in a
   presets section.
4. Click the preset to recall it; confirm sharing starts at the saved
   region's exact position and size (no overlay needed).
5. Stop sharing. Quit Skylight entirely (menu bar → Quit).
6. Relaunch Skylight (`scripts/run.sh` or open the built app again).
7. Open the menu bar; confirm the same preset is still listed.
8. Recall it again; confirm it still shares the correct region.

**Expected result:** Presets survive a full quit/relaunch and recall the
exact saved region every time.

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

---

## 6. Global hotkey toggle

**Setup:** A hotkey is configured in Skylight's settings window (set one if
none is configured yet — open the menu bar → Settings, click the hotkey
recorder field, and press a key combination).

**Steps:**

1. With Skylight idle and some other app focused (e.g., Terminal, not
   Skylight), press the configured hotkey.
2. Confirm sharing starts — using the last-used region if one exists, or
   showing the selection overlay if none does.
3. With Skylight sharing, press the hotkey again from a different focused
   app.
4. Confirm sharing stops and the virtual display disappears from System
   Settings → Displays.

**Expected result:** The hotkey starts/stops sharing regardless of which app
has focus, without needing to click the menu bar icon.

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

---

## 7. Cursor include/exclude toggle

**Steps:**

1. Open Skylight's settings window from the menu bar. Confirm a "Show
   cursor" (or similarly named) toggle exists.
2. Turn the toggle **on**. Start sharing a region. Move the mouse pointer
   inside the region.
3. In a viewer (QuickTime preview, or a call participant), confirm the
   pointer is visible in the shared output.
4. Stop sharing. Turn the toggle **off**. Start sharing again (fresh start,
   since cursor setting is documented to apply to newly started shares).
5. Move the mouse pointer inside the region again.
6. Confirm the pointer is **not** visible in the shared output.

**Expected result:** The cursor appears or is hidden in the shared output
according to the toggle's state at share start.

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

---

## 8. No phantom display after stop or quit

Run both paths.

### 8a. Stop Sharing

**Steps:**

1. Start sharing any region.
2. Confirm "Skylight Display" is listed in System Settings → Displays.
3. Menu bar → **Stop Sharing**.
4. Immediately reopen System Settings → Displays (or refresh the list by
   closing and reopening the pane).

**Expected result:** "Skylight Display" is gone. No leftover display, no
leftover mirror window (check with Mission Control / Cmd+Tab — no stray
Skylight window should appear).

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

### 8b. Quit while sharing

**Steps:**

1. Start sharing any region.
2. Confirm "Skylight Display" is listed in System Settings → Displays.
3. Quit Skylight from the menu bar (**Quit Skylight**, or Cmd+Q with the
   menu open) while still sharing — do not stop first.
4. Reopen System Settings → Displays.

**Expected result:** "Skylight Display" is gone after quit even though
sharing was never explicitly stopped first. If it is not gone, relaunch
Skylight and Stop Sharing/quit again as a recovery step, then file this as a
bug — a display must never survive quit.

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

---

## 9. Automated test suite and lint

**Steps:**

```sh
xcodegen generate
xcodebuild -project Skylight.xcodeproj -scheme Skylight \
  -derivedDataPath build -destination 'platform=macOS,arch=arm64' test
swiftformat --lint .
swiftlint
```

**Expected result:** Test run prints `TEST SUCCEEDED`. `swiftformat --lint`
and `swiftlint` report no violations.

Note: `VirtualDisplayControllerTests/testRealVirtualDisplayLifecycle` creates
a real virtual display on this machine. If it fails once in isolation, rerun
just that test before treating it as a regression — real display creation is
occasionally flaky under load.

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

---

## 10. First-run Screen Recording permission flow

**Setup:** Requires a clean permission state. Either run on a fresh macOS
user account, or remove Skylight's existing grant first:

```sh
tccutil reset ScreenCapture ng.awo.skylight
```

**Steps:**

1. Launch Skylight for the first time (or after the reset above).
2. Confirm the Screen Recording permission request appears at launch, with
   no share attempt needed.
3. Confirm a share attempt before granting shows an alert saying Screen
   Recording permission is needed, with a path to grant it (System
   Settings → Privacy & Security → Screen Recording) — and does not crash.
4. Open **System Settings → Privacy & Security → Screen Recording** and
   confirm **Skylight** appears in the app list. Turn its toggle on.
5. Quit Skylight fully and relaunch it (macOS applies the grant only after
   a restart of the app).
6. Confirm no permission request appears at this launch.
7. Menu bar → **Start Sharing…**, select a region, confirm it, and confirm
   the share starts.

**Expected result:** The permission request comes at first launch, not
mid-share. Skylight appears in the Screen Recording list right away. After
grant + relaunch, launches are prompt-free and sharing works.

**Result:** [ ] Pass  [ ] Fail — Notes: _______________________

# Skylight

![Skylight banner](assets/banner.png)

Share one part of your screen in any app that can share a display.

Skylight is a macOS menu bar utility. You select a part of your screen with a
border rectangle. Skylight creates a virtual display named "Skylight Display"
and mirrors the selected part onto it in real time. In Zoom, Google Meet,
OBS, or any other app, you share the virtual display. Viewers see only the
selected part. This is the "share portion of screen" feature from Zoom, made
generic.

## Features

- Movable, resizable selection border to pick the region. The viewport is
  fixed once sharing starts, so nothing blocks your windows during a call.
- The selection opens with your last shared viewport preselected.
- Named region presets. Save a region once, recall it from the menu.
- Global hotkey to start and stop sharing.
- A setting to show or hide the cursor in the shared output.
- HiDPI aware: the virtual display matches the pixel density of the source
  display.

## How it works

ScreenCaptureKit captures the selected region as a video stream. A
borderless window fills the virtual display and renders the captured frames.
Your conferencing app shares the virtual display like any physical screen.

> [!CAUTION]
> Skylight creates the virtual display with `CGVirtualDisplay`, a private
> CoreGraphics interface. Apple can change or remove this interface in any
> macOS update. Do not submit builds to the App Store. The interface is
> verified on macOS 26.5.

## Requirements

- macOS 14.0 or later (verified on macOS 26.5)
- Xcode with the macOS 14 SDK or later
- Homebrew packages: `xcodegen`, `swiftformat`, `swiftlint`

## Build and run

1. Install the tools: `brew install xcodegen swiftformat swiftlint`.
2. Run `scripts/release.sh`. The script builds the app and installs it to
   `/Applications/Skylight.app`. Run the app from there — macOS keeps the
   Screen Recording grant only for an app in a stable location, not a build
   folder. (For a quick Debug build in place, use `scripts/run.sh` instead.)
3. At first launch, macOS asks for Screen Recording permission. Grant it
   in System Settings → Privacy & Security → Screen Recording.
4. Start the app again. macOS applies the permission only after a restart
   of the app.

After a code change, run `scripts/release.sh` again. It quits the running
copy and reinstalls; the stable signing identity keeps the existing grant,
so macOS does not prompt again.

## Usage

1. Click the Skylight icon in the menu bar. Select "Start Sharing…".
2. Move and resize the yellow border until it covers the part you want to
   share. Press Return, or click the "Start Sharing" button in its center.
   The border disappears and the share is live.
3. In your conferencing app, share the display named "Skylight Display".
4. To stop, select "Stop Sharing" from the menu bar icon (or press the
   hotkey). To share a different part, stop and start a new share — the
   viewport is fixed while a share runs.

To save the current region as a preset, select "Save Current Region…" while
a share runs. To set the hotkey and the cursor option, select "Settings…".

## Development

```sh
xcodegen generate                          # regenerate Skylight.xcodeproj
xcodebuild -project Skylight.xcodeproj -scheme Skylight \
  -destination 'platform=macOS,arch=arm64' test        # run all tests
xcodebuild -project Skylight.xcodeproj -scheme Skylight \
  -destination 'platform=macOS,arch=arm64' test \
  -only-testing:SkylightTests/GeometryTests            # run one test class
swiftformat . && swiftlint                 # format and lint
scripts/release.sh                         # build a signed local zip
```

The manual verification checklist is in
[docs/smoke-test.md](docs/smoke-test.md). One test
(`testRealVirtualDisplayLifecycle`) creates a real virtual display, so the
suite needs a logged-in GUI session.

All `CGVirtualDisplay` usage lives in `Sources/SkylightSPI/` and
`Sources/Skylight/VirtualDisplay/`. No other module touches the private
interface.

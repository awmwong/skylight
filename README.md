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

- Movable, resizable selection border. The shared output follows your
  changes live.
- Named region presets. Save a region once, recall it from the menu.
- Global hotkey to start and stop sharing.
- A setting to show or hide the cursor in the shared output.
- HiDPI aware: the virtual display matches the pixel density of the source
  display.

## How it works

ScreenCaptureKit captures the selected region as a video stream. A
borderless window fills the virtual display and renders the captured frames.
Your conferencing app shares the virtual display like any physical screen.
When you resize the region during a share, the display keeps its size and
the output letterboxes.

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
2. Run `scripts/run.sh`. The script generates the Xcode project, builds the
   app, and starts it.
3. On the first share attempt, macOS asks for Screen Recording permission.
   Grant it in System Settings → Privacy & Security → Screen Recording.
4. Start the app again. macOS applies the permission only after a restart
   of the app.

## Usage

1. Click the Skylight icon in the menu bar. Select "Start Sharing…".
2. Move and resize the yellow border until it covers the part you want to
   share. Press Return, or click "Start Sharing".
3. In your conferencing app, share the display named "Skylight Display".
4. To adjust the shared part during a call, drag the border or its handles.
5. To stop, press Esc on the border, or select "Stop Sharing" from the menu.

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

The full specification is in [SPEC.md](SPEC.md). The manual verification
checklist is in [docs/smoke-test.md](docs/smoke-test.md). One test
(`testRealVirtualDisplayLifecycle`) creates a real virtual display, so the
suite needs a logged-in GUI session.

All `CGVirtualDisplay` usage lives in `Sources/SkylightSPI/` and
`Sources/Skylight/VirtualDisplay/`. No other module touches the private
interface.

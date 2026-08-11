import CoreGraphics
import Foundation
import os

/// Where a region's source display sits in global CG space and how dense its
/// backing store is. Injected as a closure so tests don't need live displays.
struct SourceDisplayInfo {
    let originCG: CGPoint
    let scale: CGFloat
}

/// The one place the share flow is wired together:
/// select a region → create a virtual display sized to it → capture the
/// region → render frames into the mirror window on the virtual display.
///
/// Owns the idle → selecting → sharing state machine and guarantees teardown:
/// every path out of `.sharing` (stop, failure, quit) releases the capture,
/// the mirror window, and the virtual display, in that order.
@MainActor
@Observable
final class ShareSession {
    enum State: Equatable {
        case idle
        case selecting
        case sharing
    }

    private(set) var state: State = .idle

    /// The region being shared, tracking live moves/resizes. Kept after a
    /// stop so "share the same region again" (hotkey, T9) has something to
    /// reuse.
    private(set) var currentRegion: Region?

    /// How errors reach the user. Assigned by the menu layer (NSAlert);
    /// assigned a recorder in tests.
    var onUserFacingError: ((String) -> Void)?

    private static let logger = Logger(subsystem: "com.anthony.skylight", category: "ShareSession")

    private let displayProvider: VirtualDisplayProviding
    private let selector: RegionSelecting
    private let mirror: MirrorPresenting
    private let captureFactory: (Region, SourceDisplayInfo, CaptureOptions) -> CaptureSessionControlling
    private let sourceDisplayInfo: (CGDirectDisplayID) -> SourceDisplayInfo?
    private let hasScreenRecordingPermission: () -> Bool
    private let requestScreenRecordingPermission: () -> Void
    private let captureOptions: () -> CaptureOptions

    private var displayHandle: VirtualDisplayHandle?
    private var capture: CaptureSessionControlling?
    private var framePump: Task<Void, Never>?

    // Border drags emit region changes faster than SCStream reconfiguration
    // finishes, so updates are coalesced: while one is in flight the newest
    // region waits in `pendingRegion` and is applied when the in-flight one
    // completes.
    private var pendingRegion: Region?
    private var regionUpdateTask: Task<Void, Never>?

    init(
        displayProvider: VirtualDisplayProviding,
        selector: RegionSelecting,
        mirror: MirrorPresenting,
        captureFactory: @escaping (Region, SourceDisplayInfo, CaptureOptions) -> CaptureSessionControlling,
        sourceDisplayInfo: @escaping (CGDirectDisplayID) -> SourceDisplayInfo?,
        hasScreenRecordingPermission: @escaping () -> Bool,
        requestScreenRecordingPermission: @escaping () -> Void,
        captureOptions: @escaping () -> CaptureOptions = { CaptureOptions() }
    ) {
        self.displayProvider = displayProvider
        self.selector = selector
        self.mirror = mirror
        self.captureFactory = captureFactory
        self.sourceDisplayInfo = sourceDisplayInfo
        self.hasScreenRecordingPermission = hasScreenRecordingPermission
        self.requestScreenRecordingPermission = requestScreenRecordingPermission
        self.captureOptions = captureOptions
    }

    // MARK: - Entry points

    /// Menu "Start Sharing": show the selection overlay, then share the
    /// confirmed region.
    func beginSelection() {
        guard state == .idle else { return }
        state = .selecting

        selector.present(
            onChange: { [weak self] region in self?.regionChanged(region) },
            completion: { [weak self] region in
                guard let self else { return }
                guard let region else {
                    state = .idle
                    selector.dismiss()
                    return
                }
                Task { await self.share(region, keepOverlay: true) }
            }
        )
    }

    /// Preset recall / hotkey re-share: share a known region with no overlay.
    func startSharing(with region: Region) async {
        guard state == .idle else { return }
        state = .selecting
        await share(region, keepOverlay: false)
    }

    func stopSharing() async {
        guard state == .sharing else { return }
        await teardownShare()
        state = .idle
    }

    /// Synchronous last-resort teardown for `applicationWillTerminate`. The
    /// virtual display is the only leak that can outlive the process wind-down
    /// gracelessly, so it is released synchronously; the capture stream dies
    /// with the process.
    func terminate() {
        framePump?.cancel()
        displayProvider.destroyAll()
    }

    // MARK: - Share lifecycle

    private func share(_ region: Region, keepOverlay: Bool) async {
        guard let info = preflight(region) else { return }

        do {
            try await startPipeline(region: region, info: info, keepOverlay: keepOverlay)
            currentRegion = region
            state = .sharing
        } catch {
            Self.logger.error("share start failed: \(error, privacy: .public)")
            await teardownShare()
            state = .idle
            surface("Sharing could not start: \(userDescription(of: error))")
        }
    }

    /// Everything that must be true before any resource gets created. On
    /// failure the session is already back in `.idle` with the user told why.
    private func preflight(_ region: Region) -> SourceDisplayInfo? {
        guard hasScreenRecordingPermission() else {
            requestScreenRecordingPermission()
            selector.dismiss()
            state = .idle
            surface(
                "Skylight needs Screen Recording permission. "
                    + "Grant it in System Settings → Privacy & Security → Screen Recording, then try again."
            )
            return nil
        }

        guard let info = sourceDisplayInfo(region.displayID) else {
            selector.dismiss()
            state = .idle
            surface("The selected display is no longer available.")
            return nil
        }
        return info
    }

    private func startPipeline(region: Region, info: SourceDisplayInfo, keepOverlay: Bool) async throws {
        let pixelSize = Geometry.pixelSize(forPoints: region.rect.size, scale: info.scale)
        let handle = try displayProvider.createDisplay(
            name: AppInfo.virtualDisplayName,
            widthPixels: Int(pixelSize.width),
            heightPixels: Int(pixelSize.height),
            scale: Int(info.scale)
        )
        displayHandle = handle

        let capture = captureFactory(region, info, captureOptions())
        capture.onError = { [weak self] error in
            Task { @MainActor [weak self] in self?.captureFailed(error) }
        }
        self.capture = capture
        try await capture.start()

        try await mirror.present(onDisplayID: handle.displayID)

        framePump = Task { [weak self] in
            for await sampleBuffer in capture.frames {
                guard let self, !Task.isCancelled else { return }
                mirror.enqueue(sampleBuffer)
            }
        }

        if keepOverlay {
            selector.enterSharingMode { [weak self] in
                Task { await self?.stopSharing() }
            }
        }
    }

    private func teardownShare() async {
        framePump?.cancel()
        framePump = nil
        regionUpdateTask?.cancel()
        regionUpdateTask = nil
        pendingRegion = nil

        if let capture {
            await capture.stop()
        }
        capture = nil

        mirror.dismiss()
        selector.dismiss()

        if let displayHandle {
            do {
                try displayProvider.destroyDisplay(displayHandle)
            } catch {
                Self.logger.error("destroying virtual display failed: \(error, privacy: .public)")
            }
        }
        displayHandle = nil
    }

    private func captureFailed(_ error: Error) {
        guard state == .sharing else { return }
        Task {
            await self.teardownShare()
            self.state = .idle
            self.surface("Sharing stopped: \(self.userDescription(of: error))")
        }
    }

    // MARK: - Live region updates

    /// Mid-share the virtual display keeps its size and the mirror
    /// letterboxes any aspect change (SPEC "Resolved Decisions"), so a moved
    /// or resized border only reconfigures the capture crop.
    private func regionChanged(_ region: Region) {
        guard state == .sharing, let capture else { return }
        currentRegion = region
        pendingRegion = region

        guard regionUpdateTask == nil else { return }
        regionUpdateTask = Task { [weak self] in
            while let self, let next = pendingRegion {
                pendingRegion = nil
                do {
                    try await capture.updateRegion(next)
                } catch {
                    Self.logger.error("capture reconfigure failed: \(error, privacy: .public)")
                }
            }
            self?.regionUpdateTask = nil
        }
    }

    /// Test hook: waits until the coalesced region-update queue drains.
    func settlePendingRegionUpdates() async {
        while let task = regionUpdateTask {
            await task.value
        }
    }

    private func surface(_ message: String) {
        Self.logger.error("\(message, privacy: .public)")
        onUserFacingError?(message)
    }

    private func userDescription(of error: Error) -> String {
        switch error {
        case let CaptureError.displayNotFound(displayID):
            "the source display (id \(displayID)) is gone or not capturable"
        case let MirrorError.screenNotFound(displayID):
            "the virtual display (id \(displayID)) never came online"
        case let VirtualDisplayError.invalidDimensions(width, height):
            "the region is too small to mirror (\(width)×\(height) pixels)"
        case VirtualDisplayError.creationFailed, VirtualDisplayError.settingsRejected:
            "macOS refused to create the virtual display"
        default:
            (error as NSError).localizedDescription
        }
    }
}

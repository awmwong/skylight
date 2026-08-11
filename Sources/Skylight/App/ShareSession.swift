import CoreGraphics
import Foundation
import os

/// Where a region's source display sits in global CG space and how dense its
/// backing store is. Injected as a closure so tests don't need live displays.
struct SourceDisplayInfo {
    /// The display's bounds in global CG top-left coordinates (points).
    let bounds: CGRect
    let scale: CGFloat

    var originCG: CGPoint {
        bounds.origin
    }
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
    /// stop so the hotkey's "share the same region again" path has something
    /// to reuse.
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
    private let persistLastRegion: (Region) -> Void

    private var displayHandle: VirtualDisplayHandle?
    private var capture: CaptureSessionControlling?
    private var framePump: Task<Void, Never>?

    init(
        displayProvider: VirtualDisplayProviding,
        selector: RegionSelecting,
        mirror: MirrorPresenting,
        captureFactory: @escaping (Region, SourceDisplayInfo, CaptureOptions) -> CaptureSessionControlling,
        sourceDisplayInfo: @escaping (CGDirectDisplayID) -> SourceDisplayInfo?,
        hasScreenRecordingPermission: @escaping () -> Bool,
        requestScreenRecordingPermission: @escaping () -> Void,
        captureOptions: @escaping () -> CaptureOptions = { CaptureOptions() },
        persistLastRegion: @escaping (Region) -> Void = { _ in }
    ) {
        self.displayProvider = displayProvider
        self.selector = selector
        self.mirror = mirror
        self.captureFactory = captureFactory
        self.sourceDisplayInfo = sourceDisplayInfo
        self.hasScreenRecordingPermission = hasScreenRecordingPermission
        self.requestScreenRecordingPermission = requestScreenRecordingPermission
        self.captureOptions = captureOptions
        self.persistLastRegion = persistLastRegion
    }

    // MARK: - Entry points

    /// Menu "Start Sharing": show the selection overlay, then share the
    /// confirmed region.
    func beginSelection() {
        guard state == .idle else { return }
        state = .selecting

        selector.present(
            completion: { [weak self] region in
                guard let self else { return }
                guard let region else {
                    state = .idle
                    selector.dismiss()
                    return
                }
                Task { [weak self] in await self?.share(region) }
            }
        )
    }

    /// Preset recall / hotkey re-share: share a known region with no overlay.
    /// A running share is replaced, not silently kept.
    func startSharing(with region: Region) async {
        if state == .sharing {
            await stopSharing()
        }
        guard state == .idle else { return }
        state = .selecting
        await share(region)
    }

    func stopSharing() async {
        guard state == .sharing else { return }
        // Leave .sharing before the first await so a second stop or a
        // capture error arriving mid-teardown finds the guards closed
        // instead of racing this teardown.
        state = .idle
        await teardownShare()
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

    private func share(_ requestedRegion: Region) async {
        guard let info = preflight(requestedRegion) else { return }

        // A recalled preset can be stale: the display may have moved, shrunk,
        // or changed scale since the region was saved. Clamp against the
        // display's current bounds so the capture crop always exists.
        let region = Region(
            displayID: requestedRegion.displayID,
            rect: Geometry.clamp(requestedRegion.rect, toDisplayBounds: info.bounds)
        )

        do {
            try await startPipeline(region: region, info: info)
            // The viewport is fixed once sharing starts; nothing stays on
            // screen, so the selection overlay goes away here.
            selector.dismiss()
            currentRegion = region
            persistLastRegion(region)
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

    private func startPipeline(region: Region, info: SourceDisplayInfo) async throws {
        // Same rounding as the capture output (CaptureConfig), so the display
        // and the frames it shows never differ by a letterbox sliver.
        let pixelSize = Geometry.evenPixelSize(forPoints: region.rect.size, scale: info.scale)
        let handle = try displayProvider.createDisplay(
            name: AppInfo.virtualDisplayName,
            widthPixels: pixelSize.width,
            heightPixels: pixelSize.height,
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
    }

    private func teardownShare() async {
        // Claim every resource synchronously (no await above this block), so
        // a re-entrant call finds nothing left to tear down twice.
        framePump?.cancel()
        framePump = nil
        let captureToStop = capture
        capture = nil
        let handleToDestroy = displayHandle
        displayHandle = nil

        mirror.dismiss()
        selector.dismiss()

        if let captureToStop {
            await captureToStop.stop()
        }

        if let handleToDestroy {
            do {
                try displayProvider.destroyDisplay(handleToDestroy)
            } catch {
                Self.logger.error("destroying virtual display failed: \(error, privacy: .public)")
            }
        }
    }

    private func captureFailed(_ error: Error) {
        guard state == .sharing else { return }
        state = .idle
        Task {
            await self.teardownShare()
            self.surface("Sharing stopped: \(self.userDescription(of: error))")
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

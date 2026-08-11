import CoreGraphics
import CoreMedia
@testable import Skylight

// MARK: - Fakes

@MainActor
final class FakeSelector: RegionSelecting {
    private(set) var presentCount = 0
    private(set) var dismissed = false
    private var completion: ((Region?) -> Void)?

    func present(completion: @escaping (Region?) -> Void) {
        presentCount += 1
        self.completion = completion
    }

    func dismiss() {
        dismissed = true
    }

    /// Simulates the user confirming. The share start-up it triggers is
    /// async — tests wait on an observable condition afterwards.
    func confirm(_ region: Region) {
        completion?(region)
    }

    func cancel() {
        completion?(nil)
    }
}

@MainActor
final class FakeMirror: MirrorPresenting {
    private(set) var presentedDisplayIDs: [CGDirectDisplayID] = []
    private(set) var enqueuedCount = 0
    private(set) var dismissed = false

    func present(onDisplayID displayID: CGDirectDisplayID) async throws {
        presentedDisplayIDs.append(displayID)
    }

    func enqueue(_: CMSampleBuffer) {
        enqueuedCount += 1
    }

    func dismiss() {
        dismissed = true
    }
}

final class FakeCapture: CaptureSessionControlling {
    let frames: AsyncStream<CMSampleBuffer>
    var onError: ((Error) -> Void)?

    let region: Region
    private(set) var started = false
    private(set) var stopped = false
    private(set) var stopCount = 0

    private let startError: Error?
    private var continuation: AsyncStream<CMSampleBuffer>.Continuation?

    init(region: Region, startError: Error?) {
        self.region = region
        self.startError = startError
        var continuation: AsyncStream<CMSampleBuffer>.Continuation?
        frames = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    func start() async throws {
        if let startError {
            throw startError
        }
        started = true
    }

    func stop() async {
        stopped = true
        stopCount += 1
        continuation?.finish()
    }

    func yield(_ buffer: CMSampleBuffer) {
        continuation?.yield(buffer)
    }
}

/// Wraps the shared fake with call recording ShareSession tests need.
final class RecordingDisplayProvider: VirtualDisplayProviding {
    struct CreateCall: Equatable {
        let name: String
        let widthPixels: Int
        let heightPixels: Int
        let scale: Int
    }

    private let fake = FakeVirtualDisplayProvider()
    private(set) var createCalls: [CreateCall] = []
    private(set) var lastHandle: VirtualDisplayHandle?
    private(set) var destroyAllCalled = false

    var liveDisplayIDs: Set<CGDirectDisplayID> {
        fake.liveDisplayIDs
    }

    func createDisplay(
        name: String,
        widthPixels: Int,
        heightPixels: Int,
        scale: Int
    ) throws -> VirtualDisplayHandle {
        let handle = try fake.createDisplay(
            name: name,
            widthPixels: widthPixels,
            heightPixels: heightPixels,
            scale: scale
        )
        createCalls.append(
            CreateCall(name: name, widthPixels: widthPixels, heightPixels: heightPixels, scale: scale)
        )
        lastHandle = handle
        return handle
    }

    func destroyDisplay(_ handle: VirtualDisplayHandle) throws {
        try fake.destroyDisplay(handle)
    }

    func destroyAll() {
        destroyAllCalled = true
        fake.destroyAll()
    }
}

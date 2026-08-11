import CoreMedia

/// What `ShareSession` needs from a running capture. `CaptureEngine` is the
/// real implementation; tests use a fake so no test touches
/// ScreenCaptureKit or needs Screen Recording permission.
protocol CaptureSessionControlling: AnyObject {
    var frames: AsyncStream<CMSampleBuffer> { get }
    var onError: ((Error) -> Void)? { get set }

    func start() async throws
    func stop() async
}

extension CaptureEngine: CaptureSessionControlling {}

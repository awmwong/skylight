/// What `ShareSession` needs from the selection overlay.
/// `SelectionOverlayController` is the real implementation; tests use a fake.
///
/// Lifecycle: `present` shows the overlay and reports the confirmed region
/// (or nil on cancel) through `completion`. The overlay stays up while the
/// share starts; the session dismisses it on success (the viewport is fixed
/// for the whole share, nothing stays on screen) or on failure. `dismiss`
/// removes the overlay in any state.
@MainActor
protocol RegionSelecting: AnyObject {
    func present(completion: @escaping (Region?) -> Void)
    func dismiss()
}

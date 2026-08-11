/// What `ShareSession` needs from the selection overlay.
/// `SelectionOverlayController` is the real implementation; tests use a fake.
///
/// Lifecycle: `present` shows the overlay and reports the confirmed region
/// (or nil on cancel) through `completion`, keeping the border on screen.
/// If the share starts successfully the session calls `enterSharingMode`,
/// which strips the overlay down to an adjustable border whose changes
/// arrive via `onChange`; Esc there fires `onStop`. `dismiss` removes the
/// overlay in any state.
@MainActor
protocol RegionSelecting: AnyObject {
    func present(onChange: @escaping (Region) -> Void, completion: @escaping (Region?) -> Void)
    func enterSharingMode(onStop: @escaping () -> Void)
    func dismiss()
}

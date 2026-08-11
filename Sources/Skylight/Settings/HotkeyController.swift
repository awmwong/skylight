/// What the global hotkey should do, given the session's current state and
/// the last-known region. Pure so the three branches are unit-testable
/// without touching `ShareSession` or `KeyboardShortcuts`.
enum HotkeyAction: Equatable {
    case stopSharing
    case startSharing(Region)
    case beginSelection
}

enum HotkeyController {
    /// Toggling the hotkey while sharing stops it. Otherwise it resumes the
    /// last region if one exists, or opens the selection overlay when
    /// there is none yet (first run, or after a region was never picked).
    static func action(state: ShareSession.State, lastRegion: Region?) -> HotkeyAction {
        if state == .sharing {
            return .stopSharing
        }
        if let lastRegion {
            return .startSharing(lastRegion)
        }
        return .beginSelection
    }
}

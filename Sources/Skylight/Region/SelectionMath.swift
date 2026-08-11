import CoreGraphics

/// The 8 resize handles on a selection border: the 4 corners plus the
/// midpoint of each edge.
enum SelectionHandle: CaseIterable, Equatable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
}

/// What a mouse-down on the selection border started: dragging the whole
/// rect, or resizing it from one handle.
enum SelectionDragKind: Equatable {
    case move
    case resize(SelectionHandle)
}

/// Pure hit-testing and resize math for the region selection overlay. Works
/// in whatever coordinate space the caller's rects use (the overlay view
/// uses AppKit's bottom-left, y-up view coordinates) — no NSView or NSScreen
/// calls here, so this is fully unit-testable.
enum SelectionMath {
    static let defaultHandleSize: CGFloat = 10

    // MARK: - Handle geometry

    /// The point a handle sits on: a corner, or the midpoint of an edge.
    static func handlePoint(_ handle: SelectionHandle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .top: CGPoint(x: rect.midX, y: rect.maxY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.maxY)
        case .right: CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .bottom: CGPoint(x: rect.midX, y: rect.minY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .left: CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    /// The square hit/draw area centered on a handle's point.
    static func handleRect(
        _ handle: SelectionHandle,
        in rect: CGRect,
        size: CGFloat = defaultHandleSize
    ) -> CGRect {
        let point = handlePoint(handle, in: rect)
        let half = size / 2
        return CGRect(x: point.x - half, y: point.y - half, width: size, height: size)
    }

    // MARK: - Hit testing

    /// The handle whose hit area contains `point`, if any.
    static func handle(
        at point: CGPoint,
        in rect: CGRect,
        handleSize: CGFloat = defaultHandleSize
    ) -> SelectionHandle? {
        SelectionHandle.allCases.first { handleRect($0, in: rect, size: handleSize).contains(point) }
    }

    /// What a mouse-down at `point` should start: a resize if it landed on a
    /// handle, a move if it landed inside the rect elsewhere, or nil if it
    /// missed the selection entirely.
    static func dragKind(
        at point: CGPoint,
        in rect: CGRect,
        handleSize: CGFloat = defaultHandleSize
    ) -> SelectionDragKind? {
        if let handle = handle(at: point, in: rect, handleSize: handleSize) {
            return .resize(handle)
        }
        guard rect.contains(point) else { return nil }
        return .move
    }

    // MARK: - Applying a drag

    /// The rect that results from dragging `dragKind` by `translation`,
    /// clamped to `displayBounds` and `minimumSize` via `Geometry.clamp`.
    static func updatedRect(
        for dragKind: SelectionDragKind,
        startRect: CGRect,
        translation: CGSize,
        displayBounds: CGRect,
        minimumSize: CGSize = Geometry.defaultMinimumRegionSize
    ) -> CGRect {
        let draggedRect: CGRect = switch dragKind {
        case .move:
            movedRect(startRect: startRect, translation: translation)
        case let .resize(handle):
            resizedRect(for: handle, startRect: startRect, translation: translation)
        }
        return Geometry.clamp(draggedRect, toDisplayBounds: displayBounds, minimumSize: minimumSize)
    }

    private static func movedRect(startRect: CGRect, translation: CGSize) -> CGRect {
        CGRect(
            x: startRect.minX + translation.width,
            y: startRect.minY + translation.height,
            width: startRect.width,
            height: startRect.height
        )
    }

    /// Moves the edges `handle` controls by `translation`, leaving the
    /// opposite edges fixed. Dragging a handle past its opposite edge flips
    /// the rect rather than producing negative size — the fixed edge stays
    /// put and the rect grows from there, same as a marquee-resize overshoot.
    private static func resizedRect(
        for handle: SelectionHandle,
        startRect: CGRect,
        translation: CGSize
    ) -> CGRect {
        var minX = startRect.minX
        var maxX = startRect.maxX
        var minY = startRect.minY
        var maxY = startRect.maxY

        switch handle {
        case .topLeft:
            minX += translation.width
            maxY += translation.height
        case .top:
            maxY += translation.height
        case .topRight:
            maxX += translation.width
            maxY += translation.height
        case .right:
            maxX += translation.width
        case .bottomRight:
            maxX += translation.width
            minY += translation.height
        case .bottom:
            minY += translation.height
        case .bottomLeft:
            minX += translation.width
            minY += translation.height
        case .left:
            minX += translation.width
        }

        return CGRect(
            x: min(minX, maxX),
            y: min(minY, maxY),
            width: abs(maxX - minX),
            height: abs(maxY - minY)
        )
    }

    // MARK: - Local -> global CG conversion

    /// Converts a rect in an overlay panel's local view coordinates into
    /// global CoreGraphics top-left coordinates: first offset by the panel's
    /// AppKit screen-space origin, then flip via `Geometry`.
    static func globalCGRect(localRect: CGRect, panelFrame: CGRect, primaryDisplayHeight: CGFloat) -> CGRect {
        let globalAppKitRect = CGRect(
            x: panelFrame.minX + localRect.minX,
            y: panelFrame.minY + localRect.minY,
            width: localRect.width,
            height: localRect.height
        )
        return Geometry.convertAppKitToCG(globalAppKitRect, primaryDisplayHeight: primaryDisplayHeight)
    }
}

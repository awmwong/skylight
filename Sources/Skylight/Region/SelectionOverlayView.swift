import AppKit
import CoreGraphics

/// Draws the selection border, its 8 resize handles, a dimmed mask over the
/// area outside the selection, a live size readout, and a confirm button.
/// Turns mouse drags into `SelectionMath` calls; reports the final rect back
/// in the view's own local (AppKit bottom-left) coordinates.
final class SelectionOverlayView: NSView {
    private static let handleSize = SelectionMath.defaultHandleSize
    private static let borderColor = NSColor.systemYellow
    private static let handleFillColor = NSColor.white
    private static let maskColor = NSColor.black.withAlphaComponent(0.5)
    private static let readoutMargin: CGFloat = 6

    private let displayBounds: CGRect
    private let onConfirm: (CGRect) -> Void
    private let onCancel: () -> Void

    private var selectionRect: CGRect
    private var activeDrag: SelectionDragKind?
    private var dragStartRect: CGRect = .zero
    private var dragStartLocation: CGPoint = .zero

    private let confirmButton = NSButton(title: "Start Sharing", target: nil, action: nil)
    private let readoutLabel = NSTextField(labelWithString: "")

    init(
        displayBounds: CGRect,
        initialRect: CGRect,
        onConfirm: @escaping (CGRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.displayBounds = displayBounds
        selectionRect = initialRect
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        super.init(frame: displayBounds)
        setUpSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    private func setUpSubviews() {
        confirmButton.target = self
        confirmButton.action = #selector(confirmTapped)
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"
        addSubview(confirmButton)

        readoutLabel.textColor = .white
        readoutLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        readoutLabel.backgroundColor = .clear
        readoutLabel.isBezeled = false
        readoutLabel.isEditable = false
        addSubview(readoutLabel)

        layOutSubviews()
    }

    @objc private func confirmTapped() {
        onConfirm(selectionRect)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case KeyCode.escape:
            onCancel()
        case KeyCode.returnKey:
            onConfirm(selectionRect)
        default:
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        activeDrag = SelectionMath.dragKind(at: location, in: selectionRect, handleSize: Self.handleSize)
        dragStartRect = selectionRect
        dragStartLocation = location
    }

    override func mouseDragged(with event: NSEvent) {
        guard let activeDrag else { return }
        let location = convert(event.locationInWindow, from: nil)
        let translation = CGSize(
            width: location.x - dragStartLocation.x,
            height: location.y - dragStartLocation.y
        )
        selectionRect = SelectionMath.updatedRect(
            for: activeDrag,
            startRect: dragStartRect,
            translation: translation,
            displayBounds: displayBounds
        )
        layOutSubviews()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        activeDrag = nil
    }

    /// Button and readout sit centered inside the selection, so they can
    /// never land off-screen no matter how far the selection is dragged or
    /// grown.
    private func layOutSubviews() {
        let buttonSize = confirmButton.fittingSize
        confirmButton.setFrameSize(buttonSize)
        confirmButton.setFrameOrigin(CGPoint(
            x: selectionRect.midX - buttonSize.width / 2,
            y: selectionRect.midY - buttonSize.height / 2
        ))

        readoutLabel.stringValue = "\(Int(selectionRect.width)) \u{00d7} \(Int(selectionRect.height))"
        readoutLabel.sizeToFit()
        readoutLabel.setFrameOrigin(CGPoint(
            x: selectionRect.midX - readoutLabel.frame.width / 2,
            y: selectionRect.midY + buttonSize.height / 2 + Self.readoutMargin
        ))
    }

    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)
        drawMask()
        drawBorder()
        drawHandles()
    }

    private func drawMask() {
        Self.maskColor.setFill()
        let maskPath = NSBezierPath(rect: bounds)
        maskPath.append(NSBezierPath(rect: selectionRect).reversed)
        maskPath.fill()
    }

    private func drawBorder() {
        let path = NSBezierPath(rect: selectionRect)
        path.lineWidth = 2
        path.setLineDash([6, 4], count: 2, phase: 0)
        Self.borderColor.setStroke()
        path.stroke()
    }

    private func drawHandles() {
        for handle in SelectionHandle.allCases {
            let handleRect = SelectionMath.handleRect(handle, in: selectionRect, size: Self.handleSize)
            let handlePath = NSBezierPath(ovalIn: handleRect)
            Self.handleFillColor.setFill()
            handlePath.fill()
            Self.borderColor.setStroke()
            handlePath.stroke()
        }
    }
}

private enum KeyCode {
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
}

import AppKit
import QuartzCore

@MainActor
final class EffectsController {
    private var feedbackWindow: NSPanel?
    private var closeWorkItem: DispatchWorkItem?

    func showTaskCompleted(title: String) {
        present(.completion(title))
    }

    func showReminder(title: String) {
        present(.reminder(title))
    }

    private func present(_ feedback: Feedback) {
        dismiss(animated: false)
        guard let screen = targetScreen else { return }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let endFrame = feedback.frame(on: screen)
        let panel = feedbackPanel(frame: endFrame)
        panel.contentView = FeedbackCardView(frame: NSRect(origin: .zero, size: endFrame.size), feedback: feedback, reduceMotion: reduceMotion)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        feedbackWindow = panel

        if !reduceMotion {
            animateEntrance(of: panel)
        }

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.dismiss(animated: true)
            }
        }
        closeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + feedback.duration, execute: workItem)
    }

    private func dismiss(animated: Bool) {
        closeWorkItem?.cancel()
        closeWorkItem = nil
        guard let panel = feedbackWindow else { return }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard animated, !reduceMotion else {
            panel.close()
            feedbackWindow = nil
            return
        }

        animateExit(of: panel)
        let workItem = DispatchWorkItem { [weak self, weak panel] in
            Task { @MainActor in
                panel?.close()
                if self?.feedbackWindow === panel {
                    self?.feedbackWindow = nil
                }
            }
        }
        closeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    private func animateEntrance(of panel: NSPanel) {
        guard let layer = panel.contentView?.layer else { return }

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0
        opacity.toValue = 1

        let translation = CABasicAnimation(keyPath: "transform.translation.y")
        translation.fromValue = 10
        translation.toValue = 0

        let group = CAAnimationGroup()
        group.animations = [opacity, translation]
        group.duration = 0.24
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(group, forKey: "card-arrival")
    }

    private func animateExit(of panel: NSPanel) {
        guard let layer = panel.contentView?.layer else { return }

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 1
        opacity.toValue = 0

        let translation = CABasicAnimation(keyPath: "transform.translation.y")
        translation.fromValue = 0
        translation.toValue = 6

        let group = CAAnimationGroup()
        group.animations = [opacity, translation]
        group.duration = 0.18
        group.timingFunction = CAMediaTimingFunction(name: .easeIn)
        layer.opacity = 0
        layer.add(group, forKey: "card-departure")
    }

    private func feedbackPanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        return panel
    }

    private var targetScreen: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

private enum Feedback {
    case completion(String)
    case reminder(String)

    var label: String {
        switch self {
        case .completion: "COMPLETED"
        case .reminder: "REMINDER"
        }
    }

    var title: String {
        switch self {
        case .completion(let title), .reminder(let title): title
        }
    }

    var icon: String {
        switch self {
        case .completion: "checkmark"
        case .reminder: "bell.fill"
        }
    }

    var color: NSColor {
        switch self {
        case .completion: .todoBarTeal
        case .reminder: .todoBarBlue
        }
    }

    var size: NSSize {
        switch self {
        case .completion: NSSize(width: 260, height: 64)
        case .reminder: NSSize(width: 310, height: 76)
        }
    }

    var duration: TimeInterval {
        switch self {
        case .completion: 1.8
        case .reminder: 4.5
        }
    }

    func frame(on screen: NSScreen) -> NSRect {
        let visibleFrame = screen.visibleFrame
        return NSRect(
            x: visibleFrame.maxX - size.width - 14,
            y: visibleFrame.maxY - size.height - 12,
            width: size.width,
            height: size.height
        )
    }
}

private final class FeedbackCardView: NSVisualEffectView {
    private let feedback: Feedback
    private let reduceMotion: Bool
    private let iconBackground = NSView()
    private let iconView = NSImageView()
    private let labelField = NSTextField(labelWithString: "")
    private let titleField = NSTextField(labelWithString: "")
    private let accentLayer = CALayer()

    init(frame frameRect: NSRect, feedback: Feedback, reduceMotion: Bool) {
        self.feedback = feedback
        self.reduceMotion = reduceMotion
        super.init(frame: frameRect)

        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.7).cgColor
        layer?.masksToBounds = true

        accentLayer.backgroundColor = feedback.color.cgColor
        layer?.addSublayer(accentLayer)

        configureIcon()
        configureText()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        accentLayer.frame = CGRect(x: 0, y: 0, width: 3, height: bounds.height)

        let iconSize: CGFloat = feedback.size.height == 64 ? 34 : 40
        iconBackground.frame = CGRect(
            x: 14,
            y: bounds.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        iconBackground.layer?.cornerRadius = 11
        iconView.frame = iconBackground.bounds.insetBy(dx: 9, dy: 9)

        let textX = iconBackground.frame.maxX + 12
        let textWidth = bounds.width - textX - 14
        labelField.frame = CGRect(x: textX, y: bounds.midY + 4, width: textWidth, height: 14)
        titleField.frame = CGRect(x: textX, y: bounds.midY - 18, width: textWidth, height: 20)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !reduceMotion else { return }
        layoutSubtreeIfNeeded()
        animateIcon()
        switch feedback {
        case .completion:
            animatePetals()
        case .reminder:
            animateReminderPulse()
        }
    }

    private func configureIcon() {
        iconBackground.wantsLayer = true
        iconBackground.layer?.backgroundColor = feedback.color.withAlphaComponent(0.18).cgColor

        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: feedback.icon, accessibilityDescription: feedback.label)?
            .withSymbolConfiguration(configuration)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = feedback.color

        iconBackground.addSubview(iconView)
        addSubview(iconBackground)
    }

    private func configureText() {
        labelField.stringValue = feedback.label
        labelField.font = .systemFont(ofSize: 9.5, weight: .semibold)
        labelField.textColor = feedback.color

        titleField.stringValue = feedback.title
        titleField.font = .systemFont(ofSize: 13.5, weight: .medium)
        titleField.textColor = .labelColor
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1

        addSubview(labelField)
        addSubview(titleField)
    }

    private func animateIcon() {
        let animation = CASpringAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.72
        animation.toValue = 1
        animation.mass = 0.7
        animation.stiffness = 230
        animation.damping = 15
        animation.initialVelocity = 1.5
        animation.duration = animation.settlingDuration
        iconBackground.layer?.add(animation, forKey: "arrival")
    }

    private func animatePetals() {
        let colors: [NSColor] = [.todoBarTeal, .todoBarAmber, .todoBarCoral, .todoBarBlue]
        let center = CGPoint(x: iconBackground.frame.midX, y: iconBackground.frame.midY)
        let offsets: [CGPoint] = [
            CGPoint(x: -18, y: 15),
            CGPoint(x: -22, y: -10),
            CGPoint(x: 4, y: 22),
            CGPoint(x: 22, y: 12),
            CGPoint(x: 22, y: -14),
            CGPoint(x: -4, y: -22),
        ]

        for (index, offset) in offsets.enumerated() {
            let petal = CALayer()
            petal.bounds = CGRect(x: 0, y: 0, width: 4, height: 7)
            petal.position = center
            petal.cornerRadius = 2
            petal.backgroundColor = colors[index % colors.count].cgColor
            petal.opacity = 0
            layer?.addSublayer(petal)

            let position = CAKeyframeAnimation(keyPath: "position")
            position.values = [
                center,
                CGPoint(x: center.x + offset.x * 0.55, y: center.y + offset.y * 0.55),
                CGPoint(x: center.x + offset.x, y: center.y + offset.y - 4),
            ]

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0, 0.9, 0]

            let rotation = CABasicAnimation(keyPath: "transform.rotation")
            rotation.fromValue = 0
            rotation.toValue = CGFloat.pi * (index.isMultiple(of: 2) ? 1.2 : -1.2)

            let group = CAAnimationGroup()
            group.animations = [position, opacity, rotation]
            group.beginTime = CACurrentMediaTime() + 0.08
            group.duration = 0.68
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            petal.add(group, forKey: "burst")
        }
    }

    private func animateReminderPulse() {
        let pulse = CAShapeLayer()
        pulse.frame = iconBackground.frame.insetBy(dx: -4, dy: -4)
        pulse.path = CGPath(ellipseIn: pulse.bounds, transform: nil)
        pulse.fillColor = NSColor.clear.cgColor
        pulse.strokeColor = feedback.color.withAlphaComponent(0.45).cgColor
        pulse.lineWidth = 1.5
        pulse.opacity = 0
        layer?.insertSublayer(pulse, below: iconBackground.layer)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.88
        scale.toValue = 1.38

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 0.55, 0]
        opacity.keyTimes = [0, 0.25, 1]

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.beginTime = CACurrentMediaTime() + 0.18
        group.duration = 0.9
        group.repeatCount = 2
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pulse.add(group, forKey: "pulse")
    }
}

private extension NSColor {
    static let todoBarTeal = NSColor(red: 0x16 / 255, green: 0xA7 / 255, blue: 0x99 / 255, alpha: 1)
    static let todoBarAmber = NSColor(red: 0xF7 / 255, green: 0xB3 / 255, blue: 0x12 / 255, alpha: 1)
    static let todoBarCoral = NSColor(red: 0xF4 / 255, green: 0x50 / 255, blue: 0x3C / 255, alpha: 1)
    static let todoBarBlue = NSColor(red: 0x2E / 255, green: 0x7F / 255, blue: 0xE5 / 255, alpha: 1)
}

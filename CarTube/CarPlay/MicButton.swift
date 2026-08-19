//
//  MicButton.swift
//  CarTube
//

import UIKit

enum VoiceHint {
    case noSpeech
    case unavailable
}

// Floating push-to-talk affordance for the CarPlay screen: idle/listening/hint states,
// a red pulse while listening, and a "Listening…" / hint pill anchored below the button.
final class MicButton: UIView {
    private static let diameter: CGFloat = 56.0
    private static let idleFill = UIColor(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0, alpha: 1)
    private static let hintDisplayDuration: TimeInterval = 1.5
    private static let hintFadeDuration: TimeInterval = 0.2

    private let button = UIButton(type: .custom)
    private let pillBackground = UIView()
    private let pillLabel = UILabel()

    var onTouchDown: (() -> Void)?
    var onTouchUp: (() -> Void)?

    private var hintDismissWorkItem: DispatchWorkItem?

    // The button is fixed-size (56x56, per spec) — callers only ever choose where it
    // sits. `init(origin:)` makes that contract explicit instead of accepting a width
    // and height it would silently discard.
    convenience init(origin: CGPoint) {
        self.init(frame: CGRect(origin: origin, size: CGSize(width: Self.diameter, height: Self.diameter)))
    }

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: Self.diameter, height: Self.diameter))
        setUpButton()
        setUpPill()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpButton() {
        button.frame = bounds
        button.backgroundColor = Self.idleFill
        button.layer.cornerRadius = Self.diameter / 2
        button.setImage(
            UIImage(systemName: "mic.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)),
            for: .normal
        )
        button.tintColor = .white
        button.accessibilityLabel = "Voice search"
        button.accessibilityHint = "Hold to search by voice"
        button.addTarget(self, action: #selector(handleTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        addSubview(button)
    }

    private func setUpPill() {
        pillBackground.backgroundColor = .black
        pillBackground.layer.cornerRadius = 16
        pillBackground.clipsToBounds = true
        pillBackground.isHidden = true
        pillBackground.isUserInteractionEnabled = false

        pillLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        pillLabel.textColor = .white
        pillLabel.textAlignment = .center

        pillBackground.addSubview(pillLabel)
        addSubview(pillBackground)
    }

    @objc private func handleTouchDown() {
        onTouchDown?()
    }

    @objc private func handleTouchUp() {
        onTouchUp?()
    }

    func setListening(_ listening: Bool) {
        if listening {
            button.backgroundColor = .systemRed
            showPill(text: "Listening…")
            startPulse()
        } else {
            stopListeningVisuals()
            hidePill()
        }
    }

    // Resets the button's idle appearance only — never touches the pill. A failure
    // pill shown by `onFailure` during the same touch-up call stack must survive the
    // caller's follow-up "stop listening" visual update, or the hint never renders.
    func stopListeningVisuals() {
        button.backgroundColor = Self.idleFill
        stopPulse()
    }

    // Renders a transient hint pill ("Didn't catch that" / "Voice search unavailable"),
    // fades it out after hintDisplayDuration, then invokes onDismiss so the caller can
    // re-check button visibility (support may have been withdrawn).
    func showHint(_ hint: VoiceHint, onDismiss: @escaping () -> Void) {
        let text: String
        switch hint {
        case .noSpeech:
            text = "Didn't catch that"
        case .unavailable:
            text = "Voice search unavailable"
        }
        showPill(text: text)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                onDismiss()
                return
            }
            UIView.animate(withDuration: Self.hintFadeDuration, animations: {
                self.pillBackground.alpha = 0
            }, completion: { _ in
                self.pillBackground.isHidden = true
                onDismiss()
            })
        }
        hintDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hintDisplayDuration, execute: workItem)
    }

    private func startPulse() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.1
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        button.layer.add(pulse, forKey: "voiceSearchPulse")
    }

    private func stopPulse() {
        button.layer.removeAnimation(forKey: "voiceSearchPulse")
    }

    private func showPill(text: String) {
        hintDismissWorkItem?.cancel()
        hintDismissWorkItem = nil
        pillLabel.text = text
        layoutPill()
        pillBackground.alpha = 1
        pillBackground.isHidden = false
    }

    private func hidePill() {
        hintDismissWorkItem?.cancel()
        hintDismissWorkItem = nil
        pillBackground.isHidden = true
    }

    private func layoutPill() {
        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 8
        let maxWidth = (superview?.bounds.width ?? bounds.width * 6) - horizontalPadding * 2
        let textSize = pillLabel.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        let pillWidth = textSize.width + horizontalPadding * 2
        let pillHeight = textSize.height + verticalPadding * 2
        pillBackground.frame = CGRect(x: bounds.maxX - pillWidth, y: bounds.maxY + 8, width: pillWidth, height: pillHeight)
        pillLabel.frame = pillBackground.bounds
    }
}

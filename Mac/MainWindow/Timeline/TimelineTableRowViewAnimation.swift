import AppKit
import QuartzCore

final class TimelineTableRowViewAnimation: NSView {

	func play(in highlight: NSRect) {
		self.frame = highlight

		let clippedLayer = CALayer()
		clippedLayer.masksToBounds = true

		self.layer = clippedLayer
		self.wantsLayer = true

		let color = NSColor.labelColor.withAlphaComponent(0.24)
		let animation: CABasicAnimation
		let animatedLayer: CALayer
		if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
			clippedLayer.backgroundColor = color.cgColor
			clippedLayer.opacity = 0
			animatedLayer = clippedLayer

			animation = CABasicAnimation(keyPath: "opacity")
			animation.fromValue = 1
			animation.toValue = 0
		} else {
			let tailWidth = highlight.width / 2
			let height = highlight.height
			let tipWidth = height / 2
			let sweepWidth = tailWidth + tipWidth
			let sweep = CALayer()
			sweep.anchorPoint = .zero
			sweep.bounds = CGRect(x: 0, y: 0, width: sweepWidth, height: height)
			sweep.position = CGPoint(x: highlight.width, y: 0)
			clippedLayer.addSublayer(sweep)

			let tail = CAGradientLayer()
			tail.frame = CGRect(x: 0, y: 0, width: tailWidth, height: height)
			tail.startPoint = CGPoint(x: 0, y: 0.5)
			tail.endPoint = CGPoint(x: 1, y: 0.5)
			tail.colors = [color.withAlphaComponent(0).cgColor, color.cgColor]
			sweep.addSublayer(tail)

			let path = CGMutablePath()
			path.move(to: CGPoint(x: tailWidth, y: 0))
			path.addLine(to: CGPoint(x: sweepWidth, y: height / 2))
			path.addLine(to: CGPoint(x: tailWidth, y: height))
			path.closeSubpath()

			let triangle = CAShapeLayer()
			triangle.path = path
			triangle.fillColor = color.cgColor
			sweep.addSublayer(triangle)

			animation = CABasicAnimation(keyPath: "position.x")
			animation.fromValue = -sweepWidth
			animation.toValue = highlight.width
			animatedLayer = sweep
		}

		animation.duration = 10.4
		animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

		CATransaction.begin()
		CATransaction.setCompletionBlock { [weak self, weak clippedLayer] in
			guard let self,
					let clippedLayer,
					self.layer === clippedLayer else {
				return
			}

			self.removeFromSuperview()
		}
		animatedLayer.add(animation, forKey: nil)
		CATransaction.commit()
	}

	override func hitTest(_ point: NSPoint) -> NSView? {
		return nil
	}

	override func isAccessibilityElement() -> Bool {
		return false
	}
}

import AppKit
import QuartzCore

final class TimelineTableRowViewAnimation: NSView {

	func play(in highlight: NSRect, cornerRadius: CGFloat) {
		self.frame = highlight

		let rootLayer = CALayer()
		self.layer = rootLayer
		self.wantsLayer = true

		let clippedLayer = CALayer()
		clippedLayer.frame = CGRect(origin: .zero, size: highlight.size)
		clippedLayer.cornerRadius = cornerRadius
		clippedLayer.masksToBounds = true
		rootLayer.addSublayer(clippedLayer)

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

		animation.duration = 0.4
		animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

		CATransaction.begin()
		CATransaction.setCompletionBlock { [weak self, weak rootLayer] in
			guard let self,
					let rootLayer,
					self.layer === rootLayer else {
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

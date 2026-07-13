//
//  IconView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/17/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Images

@IBDesignable
final class IconView: UIView {

	var iconImage: IconImage? {
		didSet {
			guard iconImage !== oldValue else {
				return
			}
			imageView.image = iconImage?.image
			if iconImage?.isBackgroundSuppressed ?? false {
				isDiscernable = true
			} else if traitCollection.userInterfaceStyle == .dark {
				let isDark = iconImage?.isDark ?? false
				isDiscernable = !isDark
			} else {
				let isBright = iconImage?.isBright ?? false
				isDiscernable = !isBright
			}
			setNeedsLayout()
		}
	}

	private var isDiscernable = true

	private let imageView: UIImageView = {
		let imageView = NonIntrinsicImageView(image: Assets.Images.faviconTemplate)
		imageView.contentMode = .scaleAspectFit
		imageView.clipsToBounds = true
		imageView.layer.cornerRadius = 2.0
		imageView.layer.cornerCurve = .continuous
		return imageView
	}()

	private var isVerticalBackgroundExposed: Bool {
		return imageView.frame.size.height < bounds.size.height
	}

	private var isSymbolImage: Bool {
		return iconImage?.isSymbol ?? false
	}

	private var isBackgroundSuppressed: Bool {
		return iconImage?.isBackgroundSuppressed ?? false
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	convenience init() {
		self.init(frame: .zero)
	}

	override func didMoveToSuperview() {
		setNeedsLayout()
	}

	override func layoutSubviews() {
		imageView.setFrameIfNotEqual(rectForImageView())
		updateBackgroundColor()
	}
}

private extension IconView {

	func commonInit() {
		layer.cornerRadius = 4
		clipsToBounds = true
		addSubview(imageView)
	}

	func rectForImageView() -> CGRect {
		guard !(iconImage?.isSymbol ?? false) else {
			return CGRect(x: 0.0, y: 0.0, width: bounds.size.width, height: bounds.size.height)
		}

		guard let image = iconImage?.image else {
			return CGRect.zero
		}

		let imageSize = image.size
		let viewSize = bounds.size
		guard imageSize.width > 0.0, imageSize.height > 0.0 else {
			return CGRect.zero
		}

		// Aspect-fit, but never scale up — small icons render at natural size, centered.
		let factor = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height, 1.0)
		let width = imageSize.width * factor
		let height = imageSize.height * factor
		let originX = floor((viewSize.width - width) / 2.0)
		let originY = floor((viewSize.height - height) / 2.0)
		return CGRect(x: originX, y: originY, width: width, height: height)
	}

	private func updateBackgroundColor() {
		if !isBackgroundSuppressed && ((iconImage != nil && isVerticalBackgroundExposed) || !isDiscernable) {
			backgroundColor = Assets.Colors.iconBackground
		} else {
			backgroundColor = nil
		}
	}
}

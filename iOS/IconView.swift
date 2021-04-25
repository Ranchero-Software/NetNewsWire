//
//  IconView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/17/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class IconView: UIView {

	var iconImage: IconImage? = nil {
		didSet {
			guard iconImage !== oldValue else {
				return
			}
			imageView.image = iconImage?.image
			if traitCollection.userInterfaceStyle == .dark {
				let isDark = iconImage?.isDark ?? false
				isDiscernable = !isDark
			}
			else {
				let isBright = iconImage?.isBright ?? false
				isDiscernable = !isBright
			}
			setNeedsLayout()
		}
	}

	private var isDiscernable = true

	private let imageView: UIImageView = {
		let imageView = NonIntrinsicImageView(image: AppAssets.faviconTemplateImage)
		imageView.contentMode = .scaleAspectFit
		imageView.clipsToBounds = true
		imageView.layer.cornerRadius = 2.0
		return imageView
	}()

	private var isVerticalBackgroundExposed: Bool {
		return imageView.frame.size.height < bounds.size.height
	}

	private var isSymbolImage: Bool {
		return iconImage?.isSymbol ?? false
	}
	
	private var isBackgroundSuppressed: Bool {
		return iconImage?.isBackgroundSupressed ?? false
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
		layer.cornerRadius = MasterTimelineDefaultCellLayout.iconCornerRadius
		clipsToBounds = true
		addSubview(imageView)
	}

	func rectForImageView() -> CGRect {
		guard let image = iconImage?.image else {
			return CGRect.zero
		}

		let imageSize = image.size
		let viewSize = bounds.size
		if imageSize.height == imageSize.width {
			if imageSize.height >= viewSize.height * 0.75 {
				// Close enough to viewSize to scale up the image.
				return CGRect(x: 0.0, y: 0.0, width: viewSize.width, height: viewSize.height)
			}
			let offset = floor((viewSize.height - imageSize.height) / 2.0)
			return CGRect(x: offset, y: offset, width: imageSize.width, height: imageSize.height)
		}
		else if imageSize.height > imageSize.width {
			let factor = viewSize.height / imageSize.height
			let width = imageSize.width * factor
			let originX = floor((viewSize.width - width) / 2.0)
			return CGRect(x: originX, y: 0.0, width: width, height: viewSize.height)
		}

		// Wider than tall: imageSize.width > imageSize.height
		let factor = viewSize.width / imageSize.width
		let height = imageSize.height * factor
		let originY = floor((viewSize.height - height) / 2.0)
		return CGRect(x: 0.0, y: originY, width: viewSize.width, height: height)
	}

	private func updateBackgroundColor() {
		if !isBackgroundSuppressed && ((iconImage != nil && isVerticalBackgroundExposed) || !isDiscernable) {
			backgroundColor = AppAssets.iconBackgroundColor
		} else {
			backgroundColor = nil
		}
	}
}

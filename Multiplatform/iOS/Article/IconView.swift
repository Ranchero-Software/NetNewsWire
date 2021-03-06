//
//  IconView.swift
//  Multiplatform iOS
//
//  Created by Maurice Parker on 7/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

final class IconView: UIView {

	var iconImage: IconImage? = nil {
		didSet {
			if iconImage !== oldValue {
				imageView.image = iconImage?.image

				if self.traitCollection.userInterfaceStyle == .dark {
					if self.iconImage?.isDark ?? false {
						self.isDiscernable = false
						self.setNeedsLayout()
					} else {
						self.isDiscernable = true
						self.setNeedsLayout()
					}
				} else {
					if self.iconImage?.isBright ?? false {
						self.isDiscernable = false
						self.setNeedsLayout()
					} else {
						self.isDiscernable = true
						self.setNeedsLayout()
					}
				}
				self.setNeedsLayout()
			}
		}
	}

	private var isDiscernable = true
	
	private let imageView: UIImageView = {
		let imageView = UIImageView(image: AppAssets.faviconTemplateImage)
		imageView.contentMode = .scaleAspectFit
		imageView.clipsToBounds = true
		imageView.layer.cornerRadius = 4.0
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
		if (iconImage != nil && isVerticalBackgroundExposed) || !isDiscernable {
			backgroundColor = AppAssets.uiIconBackgroundColor
		} else {
			backgroundColor = nil
		}
	}

}

private extension IconView {

	func commonInit() {
		layer.cornerRadius = 4
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
			if imageSize.height >= viewSize.height {
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

}

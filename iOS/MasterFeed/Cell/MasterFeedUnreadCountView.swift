//
//  MasterUnreadCountView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/22/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import UIKit

class MasterFeedUnreadCountView : UIView {
	
	var padding: UIEdgeInsets {
		return UIEdgeInsets(top: 1.0, left: 9.0, bottom: 1.0, right: 9.0)
	}
	
	let cornerRadius = 8.0
	let bgColor = AppAssets.controlBackgroundColor
	var textColor: UIColor {
		return UIColor.white
	}
	
	var textAttributes: [NSAttributedString.Key: AnyObject] {
		let textFont = UIFont.preferredFont(forTextStyle: .caption1).bold()
		return [NSAttributedString.Key.foregroundColor: textColor, NSAttributedString.Key.font: textFont, NSAttributedString.Key.kern: NSNull()]
	}
	var textSizeCache = [Int: CGSize]()

	var unreadCount = 0 {
		didSet {
			contentSizeIsValid = false
			invalidateIntrinsicContentSize()
			setNeedsDisplay()
		}
	}
	
	var unreadCountString: String {
		return unreadCount < 1 ? "" : "\(unreadCount)"
	}

	private var contentSizeIsValid = false
	private var _contentSize = CGSize.zero

	override init(frame: CGRect) {
		super.init(frame: frame)
		self.isOpaque = false
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.isOpaque = false
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		textSizeCache = [Int: CGSize]()
		contentSizeIsValid = false
		setNeedsDisplay()
	}
	
	var contentSize: CGSize {
		if !contentSizeIsValid {
			var size = CGSize.zero
			if unreadCount > 0 {
				size = textSize()
				size.width += (padding.left + padding.right)
				size.height += (padding.top + padding.bottom)
			}
			_contentSize = size
			contentSizeIsValid = true
		}
		return _contentSize
	}
	
	// Prevent autolayout from messing around with our frame settings
	override var intrinsicContentSize: CGSize {
		return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
	}

	func textSize() -> CGSize {

		if unreadCount < 1 {
			return CGSize.zero
		}

		if let cachedSize = textSizeCache[unreadCount] {
			return cachedSize
		}

		var size = unreadCountString.size(withAttributes: textAttributes)
		size.height = ceil(size.height)
		size.width = ceil(size.width)

		textSizeCache[unreadCount] = size
		return size
		
	}

	func textRect() -> CGRect {

		let size = textSize()
		var r = CGRect.zero
		r.size = size
		r.origin.x = (bounds.maxX - padding.right) - r.size.width
		r.origin.y = padding.top
		return r
		
	}

	override func draw(_ dirtyRect: CGRect) {

		let cornerRadii = CGSize(width: cornerRadius, height: cornerRadius)
		let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: .allCorners, cornerRadii: cornerRadii)
		bgColor.setFill()
		path.fill()

		if unreadCount > 0 {
			unreadCountString.draw(at: textRect().origin, withAttributes: textAttributes)
		}
		
	}
	
}


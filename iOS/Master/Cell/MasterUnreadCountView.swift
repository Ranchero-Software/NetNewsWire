//
//  MasterUnreadCountView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/22/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import UIKit

private let padding = UIEdgeInsets(top: 1.0, left: 7.0, bottom: 1.0, right: 7.0)
private let cornerRadius = 8.0
private let bgColor = UIColor.darkGray
private let textColor = UIColor.white
private let textFont = UIFont.systemFont(ofSize: 11.0, weight: UIFont.Weight.semibold)
private var textAttributes: [NSAttributedString.Key: AnyObject] = [NSAttributedString.Key.foregroundColor: textColor, NSAttributedString.Key.font: textFont, NSAttributedString.Key.kern: NSNull()]
private var textSizeCache = [Int: CGSize]()

class MasterUnreadCountView : UIView {
	
	var unreadCount = 0 {
		didSet {
			invalidateIntrinsicContentSize()
			setNeedsDisplay()
		}
	}
	
	var unreadCountString: String {
		return unreadCount < 1 ? "" : "\(unreadCount)"
	}

	private var intrinsicContentSizeIsValid = false
	private var _intrinsicContentSize = CGSize.zero

	override init(frame: CGRect) {
		super.init(frame: frame)
		self.isOpaque = false
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.isOpaque = false
	}
	
	override var intrinsicContentSize: CGSize {
		if !intrinsicContentSizeIsValid {
			var size = CGSize.zero
			if unreadCount > 0 {
				size = textSize()
				size.width += (padding.left + padding.right)
				size.height += (padding.top + padding.bottom)
			}
			_intrinsicContentSize = size
			intrinsicContentSizeIsValid = true
		}
		return _intrinsicContentSize
	}
	
	override func invalidateIntrinsicContentSize() {
		intrinsicContentSizeIsValid = false
	}

	private func textSize() -> CGSize {

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

	private func textRect() -> CGRect {

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


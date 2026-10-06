//
//  UILabel+UnreadCount.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/6/26.
//

import UIKit

extension UILabel {

	/// Shows `unreadCount` per the Unread Counts setting: the number, a dot, or nothing.
	/// The dot is drawn in the label’s text color.
	func setUnreadCount(_ unreadCount: Int) {
		let unreadCountDisplay = AppDefaults.shared.unreadCountDisplay
		if unreadCountDisplay.showsDot(for: unreadCount) {
			attributedText = NSAttributedString(attachment: unreadDotAttachment())
		} else {
			text = unreadCountDisplay.text(for: unreadCount)
		}
	}
}

private extension UILabel {

	func unreadDotAttachment() -> NSTextAttachment {
		let dimension = MainTimelineDefaultCellLayout.unreadCircleDimension
		let image = Assets.Images.unreadCellIndicator.image.withRenderingMode(.alwaysTemplate)
		let attachment = NSTextAttachment(image: image)
		attachment.bounds = CGRect(x: 0, y: (font.capHeight - dimension) / 2, width: dimension, height: dimension)
		return attachment
	}
}

//
//  TimelineColumnCellViews.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/19/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit

// Cell views for the timeline’s column layout. Selection state arrives through backgroundStyle,
// which the standard NSTableRowView sets, so no custom row view is needed.

private let columnCellHorizontalPadding: CGFloat = 8.0
private let feedIconDimension: CGFloat = 16.0
private let feedIconMarginRight: CGFloat = 5.0

final class TimelineUnreadColumnCellView: NSTableCellView {

	private let unreadIndicatorView = UnreadIndicatorView()

	var isUnread = false {
		didSet {
			unreadIndicatorView.isHidden = !isUnread
		}
	}

	override var backgroundStyle: NSView.BackgroundStyle {
		didSet {
			let isEmphasized = backgroundStyle == .emphasized
			unreadIndicatorView.isSelected = isEmphasized
			unreadIndicatorView.isEmphasized = isEmphasized
		}
	}

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		unreadIndicatorView.translatesAutoresizingMaskIntoConstraints = false
		unreadIndicatorView.isHidden = true
		addSubview(unreadIndicatorView)
		NSLayoutConstraint.activate([
			unreadIndicatorView.widthAnchor.constraint(equalToConstant: UnreadIndicatorView.unreadCircleDimension),
			unreadIndicatorView.heightAnchor.constraint(equalToConstant: UnreadIndicatorView.unreadCircleDimension),
			unreadIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
			unreadIndicatorView.centerYAnchor.constraint(equalTo: centerYAnchor)
		])
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
}

final class TimelineStarColumnCellView: NSTableCellView {

	private let starImageView = NSImageView(image: Assets.Images.timelineStar)

	var isStarred = false {
		didSet {
			starImageView.isHidden = !isStarred
		}
	}

	override var backgroundStyle: NSView.BackgroundStyle {
		didSet {
			starImageView.contentTintColor = backgroundStyle == .emphasized ? .white : Assets.Colors.star
		}
	}

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		starImageView.translatesAutoresizingMaskIntoConstraints = false
		starImageView.imageScaling = .scaleNone
		starImageView.contentTintColor = Assets.Colors.star
		starImageView.isHidden = true
		addSubview(starImageView)
		NSLayoutConstraint.activate([
			starImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
			starImageView.centerYAnchor.constraint(equalTo: centerYAnchor)
		])
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
}

/// Single line of truncating text — used for the Title and Date columns.
final class TimelineTextColumnCellView: NSTableCellView {

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		let label = TimelineTextColumnCellView.makeLabel()
		addSubview(label)
		textField = label
		NSLayoutConstraint.activate([
			label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: columnCellHorizontalPadding),
			label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -columnCellHorizontalPadding),
			label.centerYAnchor.constraint(equalTo: centerYAnchor)
		])
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	static func makeLabel() -> NSTextField {
		let label = NSTextField(labelWithString: "")
		label.translatesAutoresizingMaskIntoConstraints = false
		label.lineBreakMode = .byTruncatingTail
		label.maximumNumberOfLines = 1
		label.cell?.truncatesLastVisibleLine = true
		label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		return label
	}
}

/// Feed icon plus feed name.
final class TimelineFeedColumnCellView: NSTableCellView {

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		let iconView = NSImageView()
		iconView.translatesAutoresizingMaskIntoConstraints = false
		iconView.imageScaling = .scaleProportionallyDown
		iconView.wantsLayer = true
		iconView.layer?.cornerRadius = 2.0
		iconView.layer?.masksToBounds = true
		addSubview(iconView)
		imageView = iconView

		let label = TimelineTextColumnCellView.makeLabel()
		addSubview(label)
		textField = label

		NSLayoutConstraint.activate([
			iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: columnCellHorizontalPadding),
			iconView.widthAnchor.constraint(equalToConstant: feedIconDimension),
			iconView.heightAnchor.constraint(equalToConstant: feedIconDimension),
			iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
			label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: feedIconMarginRight),
			label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -columnCellHorizontalPadding),
			label.centerYAnchor.constraint(equalTo: centerYAnchor)
		])
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
}

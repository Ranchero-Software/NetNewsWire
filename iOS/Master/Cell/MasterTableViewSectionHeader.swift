//
//  MasterTableViewSectionHeader.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class MasterTableViewSectionHeader: UITableViewHeaderFooterView {
	
	override var accessibilityLabel: String? {
		set {}
		get {
			if unreadCount > 0 {
				let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessiblity")
				return "\(name) \(unreadCount) \(unreadLabel)"
			} else {
				return name
			}
		}
	}
	
	var unreadCount: Int {
		get {
			return unreadCountView.unreadCount
		}
		set {
			if unreadCountView.unreadCount != newValue {
				unreadCountView.unreadCount = newValue
				unreadCountView.isHidden = (newValue < 1)
				setNeedsLayout()
			}
		}
	}
	
	var name: String {
		get {
			return titleView.text ?? ""
		}
		set {
			if titleView.text != newValue {
				titleView.text = newValue
				setNeedsDisplay()
				setNeedsLayout()
			}
		}
	}
	
	private let titleView: UILabel = {
		let label = UILabel()
		label.font = UIFont.boldSystemFont(ofSize: 17.0)
		label.numberOfLines = 1
		label.lineBreakMode = .byTruncatingTail
		label.allowsDefaultTighteningForTruncation = false
		return label
	}()
	
	private let unreadCountView = MasterUnreadCountView(frame: CGRect.zero)
	
	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		commonInit()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		let layout = MasterTableViewCellLayout(cellSize: bounds.size, insets: safeAreaInsets, shouldShowImage: false, label: titleView, unreadCountView: unreadCountView, showingEditingControl: false, indent: true, shouldShowDisclosure: false)
		layoutWith(layout)
	}
	
}

private extension MasterTableViewSectionHeader {
	
	func commonInit() {
		let view = UIView()
		view.backgroundColor = AppAssets.tableSectionHeaderColor
		backgroundView = view
		addSubviewAtInit(unreadCountView)
		addSubviewAtInit(titleView)
	}
	
	func addSubviewAtInit(_ view: UIView) {
		addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
	}
	
	func layoutWith(_ layout: MasterTableViewCellLayout) {
		titleView.setFrameIfNotEqual(layout.titleRect)
		unreadCountView.setFrameIfNotEqual(layout.unreadCountRect)
	}
	
}

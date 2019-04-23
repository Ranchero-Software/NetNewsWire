//
//  MasterTableViewSectionHeader.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class MasterFeedTableViewSectionHeader: UITableViewHeaderFooterView {
	
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
	
	var disclosureExpanded = false {
		didSet {
			updateDisclosureImage()
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
	
	private let unreadCountView = MasterFeedUnreadCountView(frame: CGRect.zero)
	private var disclosureView: UIImageView = {
		let iView = UIImageView()
		iView.contentMode = .center
		return iView
	}()

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
		let layout = MasterFeedTableViewCellLayout(cellSize: bounds.size, insets: safeAreaInsets, shouldShowImage: false, label: titleView, unreadCountView: unreadCountView, showingEditingControl: false, indent: true, shouldShowDisclosure: true)
		layoutWith(layout)
	}
	

}

private extension MasterFeedTableViewSectionHeader {
	
	func commonInit() {
		let view = UIView()
		view.backgroundColor = AppAssets.tableSectionHeaderColor
		backgroundView = view
		addSubviewAtInit(unreadCountView)
		addSubviewAtInit(titleView)
		updateDisclosureImage()
		addSubviewAtInit(disclosureView)
	}
	
	func updateDisclosureImage() {
		if disclosureExpanded {
			disclosureView.image = AppAssets.chevronDownImage
		} else {
			disclosureView.image = AppAssets.chevronRightImage
		}
	}

	func addSubviewAtInit(_ view: UIView) {
		addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
	}
	
	func layoutWith(_ layout: MasterFeedTableViewCellLayout) {
		titleView.setFrameIfNotEqual(layout.titleRect)
		unreadCountView.setFrameIfNotEqual(layout.unreadCountRect)
		disclosureView.setFrameIfNotEqual(layout.disclosureButtonRect)
	}
	
}

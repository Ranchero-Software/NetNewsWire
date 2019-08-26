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
		let label = NonIntrinsicLabel()
		label.numberOfLines = 0
		label.allowsDefaultTighteningForTruncation = false
		label.adjustsFontForContentSizeCategory = true
		label.font = .preferredFont(forTextStyle: .body)
		return label
	}()
	
	private let unreadCountView = MasterFeedUnreadCountView(frame: CGRect.zero)
	private var disclosureView: UIImageView = {
		let iView = NonIntrinsicImageView()
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
	
	override func sizeThatFits(_ size: CGSize) -> CGSize {
		
		let unreadCountView = MasterFeedUnreadCountView(frame: CGRect.zero)

		// Since we can't reload Section Headers to reset the height after we get the
		// unread count did change, we always assume a large unread count
		//
		// This means that sometimes on the second to largest font size will have extra
		// space under the account name.  This is better than having it overflow into the
		// cell below.
		unreadCountView.unreadCount = 888
		
		let layout = MasterFeedTableViewCellLayout(cellWidth: size.width, insets: safeAreaInsets, shouldShowImage: false, label: titleView, unreadCountView: unreadCountView, showingEditingControl: false, indent: false, shouldShowDisclosure: true)
		
		return CGSize(width: bounds.width, height: layout.height)
		
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		let layout = MasterFeedTableViewCellLayout(cellWidth: bounds.size.width, insets: safeAreaInsets, shouldShowImage: false, label: titleView, unreadCountView: unreadCountView, showingEditingControl: false, indent: false, shouldShowDisclosure: true)
		layoutWith(layout)
	}

}

private extension MasterFeedTableViewSectionHeader {
	
	func commonInit() {
		addSubviewAtInit(unreadCountView)
		addSubviewAtInit(titleView)
		updateDisclosureImage()
		addSubviewAtInit(disclosureView)
		addBackgroundView()
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
	
	func addBackgroundView() {
		self.backgroundView = UIView(frame: self.bounds)
		self.backgroundView?.backgroundColor = UIColor.systemGroupedBackground
	}
	
}

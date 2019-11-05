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
				updateUnreadCountView()
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
			updateExpandedState()
			updateUnreadCountView()
		}
	}
	
	var isLastSection = false
	
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
		iView.tintColor = UIColor.tertiaryLabel
		iView.image = AppAssets.disclosureImage
		iView.contentMode = .center
		return iView
	}()

	private let topSeparatorView: UIView = {
		let view = UIView()
		view.backgroundColor = UIColor.separator
		return view
	}()
	
	private let bottomSeparatorView: UIView = {
		let view = UIView()
		view.backgroundColor = UIColor.separator
		return view
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
		let layout = MasterFeedTableViewSectionHeaderLayout(cellWidth: size.width, insets: safeAreaInsets, label: titleView, unreadCountView: unreadCountView)
		return CGSize(width: bounds.width, height: layout.height)
		
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		let layout = MasterFeedTableViewSectionHeaderLayout(cellWidth: bounds.size.width, insets: safeAreaInsets, label: titleView, unreadCountView: unreadCountView)
		layoutWith(layout)
	}

}

private extension MasterFeedTableViewSectionHeader {
	
	func commonInit() {
		addSubviewAtInit(unreadCountView)
		addSubviewAtInit(titleView)
		updateExpandedState()
		addSubviewAtInit(disclosureView)
		addBackgroundView()
		addSubviewAtInit(topSeparatorView)
		addSubviewAtInit(bottomSeparatorView)
	}
	
	func updateExpandedState() {
		if !isLastSection && self.disclosureExpanded {
			self.bottomSeparatorView.isHidden = false
		}
		UIView.animate(
			withDuration: 0.3,
			animations: {
				if self.disclosureExpanded {
					self.disclosureView.transform = CGAffineTransform(rotationAngle: 1.570796)
				} else {
					self.disclosureView.transform = CGAffineTransform(rotationAngle: 0)
				}
			}, completion: { _ in
				if !self.isLastSection && !self.disclosureExpanded {
					self.bottomSeparatorView.isHidden = true
				}
			})
	}
	
	func updateUnreadCountView() {
		if !disclosureExpanded && unreadCount > 0 {
			UIView.animate(withDuration: 0.3) {
				self.unreadCountView.alpha = 1
			}
		} else {
			UIView.animate(withDuration: 0.3) {
				self.unreadCountView.alpha = 0
			}
		}
	}

	func addSubviewAtInit(_ view: UIView) {
		addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
	}
	
	func layoutWith(_ layout: MasterFeedTableViewSectionHeaderLayout) {
		titleView.setFrameIfNotEqual(layout.titleRect)
		unreadCountView.setFrameIfNotEqual(layout.unreadCountRect)
		disclosureView.setFrameIfNotEqual(layout.disclosureButtonRect)
		
		let top = CGRect(x: safeAreaInsets.left, y: 0, width: frame.width - safeAreaInsets.right - safeAreaInsets.left, height: 0.33)
		topSeparatorView.setFrameIfNotEqual(top)
		let bottom = CGRect(x: safeAreaInsets.left, y: frame.height - 0.33, width: frame.width - safeAreaInsets.right - safeAreaInsets.left, height: 0.33)
		bottomSeparatorView.setFrameIfNotEqual(bottom)
	}
	
	func addBackgroundView() {
		self.backgroundView = UIView(frame: self.bounds)
		self.backgroundView?.backgroundColor = AppAssets.sectionHeaderColor
	}
	
}

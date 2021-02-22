//
//  MasterTableViewCell.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import RSCore
import Account
import RSTree

protocol MasterFeedTableViewCellDelegate: AnyObject {
	func masterFeedTableViewCellDisclosureDidToggle(_ sender: MasterFeedTableViewCell, expanding: Bool)
}

class MasterFeedTableViewCell : VibrantTableViewCell {

	weak var delegate: MasterFeedTableViewCellDelegate?

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

	var iconImage: IconImage? {
		didSet {
			iconView.iconImage = iconImage
		}
	}

	var isDisclosureAvailable = false {
		didSet {
			if isDisclosureAvailable != oldValue {
				setNeedsLayout()
			}
		}
	}
	
	var isSeparatorShown = true {
		didSet {
			if isSeparatorShown != oldValue {
				if isSeparatorShown {
					showView(bottomSeparatorView)
				} else {
					hideView(bottomSeparatorView)
				}
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
				setNeedsLayout()
			}
		}
	}

	private let titleView: UILabel = {
		let label = NonIntrinsicLabel()
		label.numberOfLines = 0
		label.allowsDefaultTighteningForTruncation = false
		label.adjustsFontForContentSizeCategory = true
		label.lineBreakMode = .byTruncatingTail
		label.font = .preferredFont(forTextStyle: .body)
		return label
	}()

	private let iconView = IconView()

	private let bottomSeparatorView: UIView = {
		let view = UIView()
		view.backgroundColor = UIColor.separator
		view.alpha = 0.5
		return view
	}()
	
	private var isDisclosureExpanded = false
	private var disclosureButton: UIButton?
	private var unreadCountView = MasterFeedUnreadCountView(frame: CGRect.zero)
	private var isShowingEditControl = false
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	func setDisclosure(isExpanded: Bool, animated: Bool) {
		isDisclosureExpanded = isExpanded
		let duration = animated ? 0.3 : 0.0

		UIView.animate(withDuration: duration) {
			if self.isDisclosureExpanded {
				self.disclosureButton?.accessibilityLabel = NSLocalizedString("Collapse Folder", comment: "Collapse Folder")
				self.disclosureButton?.imageView?.transform = CGAffineTransform(rotationAngle: 1.570796)
			} else {
				self.disclosureButton?.accessibilityLabel = NSLocalizedString("Expand Folder", comment: "Expand Folder") 
				self.disclosureButton?.imageView?.transform = CGAffineTransform(rotationAngle: 0)
			}
		}
	}
	
	override func applyThemeProperties() {
		super.applyThemeProperties()
	}

	override func willTransition(to state: UITableViewCell.StateMask) {
		super.willTransition(to: state)
		isShowingEditControl = state.contains(.showingEditControl)
	}
	
	override func sizeThatFits(_ size: CGSize) -> CGSize {
		let layout = MasterFeedTableViewCellLayout(cellWidth: bounds.size.width, insets: safeAreaInsets, label: titleView, unreadCountView: unreadCountView, showingEditingControl: isShowingEditControl, indent: indentationLevel == 1, shouldShowDisclosure: isDisclosureAvailable)
		return CGSize(width: bounds.width, height: layout.height)
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		let layout = MasterFeedTableViewCellLayout(cellWidth: bounds.size.width, insets: safeAreaInsets, label: titleView, unreadCountView: unreadCountView, showingEditingControl: isShowingEditControl, indent: indentationLevel == 1, shouldShowDisclosure: isDisclosureAvailable)
		layoutWith(layout)
	}
	
	@objc func buttonPressed(_ sender: UIButton) {
		if isDisclosureAvailable {
			setDisclosure(isExpanded: !isDisclosureExpanded, animated: true)
			delegate?.masterFeedTableViewCellDisclosureDidToggle(self, expanding: isDisclosureExpanded)
		}
	}
	
	override func updateVibrancy(animated: Bool) {
		super.updateVibrancy(animated: animated)
		
		let iconTintColor: UIColor
		if isHighlighted || isSelected {
			iconTintColor = AppAssets.vibrantTextColor
		} else {
			if let preferredColor = iconImage?.preferredColor {
				iconTintColor = UIColor(cgColor: preferredColor)
			} else {
				iconTintColor = AppAssets.secondaryAccentColor
			}
		}
		
		if animated {
			UIView.animate(withDuration: Self.duration) {
				self.iconView.tintColor = iconTintColor
			}
		} else {
			self.iconView.tintColor = iconTintColor
		}
		
		updateLabelVibrancy(titleView, color: labelColor, animated: animated)
	}
	
}

private extension MasterFeedTableViewCell {

	func commonInit() {
		addSubviewAtInit(unreadCountView)
		addSubviewAtInit(iconView)
		addSubviewAtInit(titleView)
		addDisclosureView()
		addSubviewAtInit(bottomSeparatorView)
	}

	func addDisclosureView() {
		disclosureButton = NonIntrinsicButton(type: .roundedRect)
		disclosureButton!.addTarget(self, action: #selector(buttonPressed(_:)), for: UIControl.Event.touchUpInside)
		disclosureButton?.setImage(AppAssets.disclosureImage, for: .normal)
		disclosureButton?.tintColor = AppAssets.controlBackgroundColor
		disclosureButton?.imageView?.contentMode = .center
		disclosureButton?.imageView?.clipsToBounds = false
		if #available(iOS 13.4, *) {
			disclosureButton?.addInteraction(UIPointerInteraction())
		}
		addSubviewAtInit(disclosureButton!)
	}
	
	func addSubviewAtInit(_ view: UIView) {
		addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
	}

	func layoutWith(_ layout: MasterFeedTableViewCellLayout) {
		iconView.setFrameIfNotEqual(layout.faviconRect)
		titleView.setFrameIfNotEqual(layout.titleRect)
		unreadCountView.setFrameIfNotEqual(layout.unreadCountRect)
		disclosureButton?.setFrameIfNotEqual(layout.disclosureButtonRect)
		disclosureButton?.isHidden = !isDisclosureAvailable
		bottomSeparatorView.setFrameIfNotEqual(layout.separatorRect)
	}

	func hideView(_ view: UIView) {
		if !view.isHidden {
			view.isHidden = true
		}
	}
	
	func showView(_ view: UIView) {
		if view.isHidden {
			view.isHidden = false
		}
	}
	
}

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

protocol MasterFeedTableViewCellDelegate: class {
	func disclosureSelected(_ sender: MasterFeedTableViewCell, expanding: Bool)
}

class MasterFeedTableViewCell : NNWTableViewCell {

	weak var delegate: MasterFeedTableViewCellDelegate?
	var isDisclosureAvailable = false
	
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

	var disclosureExpanded = false {
		didSet {
			updateDisclosureImage()
		}
	}
	
	var faviconImage: UIImage? {
		didSet {
			faviconImageView.image = faviconImage
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
		label.font = .preferredFont(forTextStyle: .body)
		return label
	}()

	private let faviconImageView: UIImageView = {
		let imageView = NonIntrinsicImageView(image: AppAssets.faviconTemplateImage)
		imageView.layer.cornerRadius = MasterFeedTableViewCellLayout.faviconCornerRadius
		imageView.clipsToBounds = true
		return imageView
	}()

	private var unreadCountView = MasterFeedUnreadCountView(frame: CGRect.zero)
	private var showingEditControl = false
	var disclosureButton: UIButton?
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	override func applyThemeProperties() {
		super.applyThemeProperties()
		titleView.highlightedTextColor = AppAssets.tableViewCellHighlightedTextColor
	}

	override func setHighlighted(_ highlighted: Bool, animated: Bool) {
		super.setHighlighted(highlighted, animated: animated)

		let tintColor = isHighlighted || isSelected ? AppAssets.tableViewCellHighlightedTextColor : AppAssets.secondaryAccentColor
		disclosureButton?.tintColor  = tintColor
		faviconImageView.tintColor = tintColor
	}

	override func setSelected(_ selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)

		let tintColor = isHighlighted || isSelected ? AppAssets.tableViewCellHighlightedTextColor : AppAssets.secondaryAccentColor
		disclosureButton?.tintColor  = tintColor
		faviconImageView.tintColor = tintColor
	}
	
	override func willTransition(to state: UITableViewCell.StateMask) {
		super.willTransition(to: state)
		showingEditControl = state.contains(.showingEditControl)
	}
	
	override func sizeThatFits(_ size: CGSize) -> CGSize {
		let layout = MasterFeedTableViewCellLayout(cellWidth: bounds.size.width, insets: safeAreaInsets, label: titleView, unreadCountView: unreadCountView, showingEditingControl: showingEditControl, indent: indentationLevel == 1, shouldShowDisclosure: isDisclosureAvailable)
		return CGSize(width: bounds.width, height: layout.height)
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		let layout = MasterFeedTableViewCellLayout(cellWidth: bounds.size.width, insets: safeAreaInsets, label: titleView, unreadCountView: unreadCountView, showingEditingControl: showingEditControl, indent: indentationLevel == 1, shouldShowDisclosure: isDisclosureAvailable)
		layoutWith(layout)
	}
	
	@objc func buttonPressed(_ sender: UIButton) {
		if isDisclosureAvailable {
			disclosureExpanded = !disclosureExpanded
			delegate?.disclosureSelected(self, expanding: disclosureExpanded)
		}
	}
	
}

private extension MasterFeedTableViewCell {

	func commonInit() {
		addSubviewAtInit(unreadCountView)
		addSubviewAtInit(faviconImageView)
		addSubviewAtInit(titleView)
		addDisclosureView()
	}

	func addDisclosureView() {
		disclosureButton = NonIntrinsicButton(type: .roundedRect)
		disclosureButton!.addTarget(self, action: #selector(buttonPressed(_:)), for: UIControl.Event.touchUpInside)
		disclosureButton?.setImage(AppAssets.chevronBaseImage, for: .normal)
		updateDisclosureImage()
		addSubviewAtInit(disclosureButton!)
	}
	
	func updateDisclosureImage() {
		UIView.animate(withDuration: 0.3) {
			if self.disclosureExpanded {
				self.disclosureButton?.imageView?.transform = CGAffineTransform(rotationAngle: 1.570796)
			} else {
				self.disclosureButton?.imageView?.transform = CGAffineTransform(rotationAngle: 0)
			}
		}
	}

	func addSubviewAtInit(_ view: UIView) {
		addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
	}

	func layoutWith(_ layout: MasterFeedTableViewCellLayout) {
		faviconImageView.setFrameIfNotEqual(layout.faviconRect)
		titleView.setFrameIfNotEqual(layout.titleRect)
		unreadCountView.setFrameIfNotEqual(layout.unreadCountRect)
		disclosureButton?.setFrameIfNotEqual(layout.disclosureButtonRect)
		disclosureButton?.isHidden = !isDisclosureAvailable
		separatorInset = layout.separatorInsets
	}
	
}

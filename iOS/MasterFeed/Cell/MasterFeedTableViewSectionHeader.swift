//
//  MasterTableViewSectionHeader.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

protocol MasterFeedTableViewSectionHeaderDelegate {
	func masterFeedTableViewSectionHeaderDisclosureDidToggle(_ sender: MasterFeedTableViewSectionHeader)
}

class MasterFeedTableViewSectionHeader: UITableViewHeaderFooterView {
	
	var delegate: MasterFeedTableViewSectionHeaderDelegate?
	
	override var accessibilityLabel: String? {
		set {}
		get {
			return "\(name) \(expandedStateMessage)"
		}
	}

	private var expandedStateMessage: String {
		set {}
		get {
			if disclosureExpanded {
				return NSLocalizedString("EXPANDED", comment: "Disclosure button expanded state for accessibility")
			}
			return NSLocalizedString("COLLAPSED", comment: "Disclosure button collapsed state for accessibility")
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
	
	var disclosureExpanded = false {
		didSet {
			updateExpandedState(animate: true)
		}
	}
	
	var isLastSection = false
	
	private let titleView: UILabel = {
		let label = NonIntrinsicLabel()
		label.numberOfLines = 0
		label.allowsDefaultTighteningForTruncation = false
		label.adjustsFontForContentSizeCategory = true
		label.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .title2).pointSize, weight: .bold)
		return label
	}()
	
	private lazy var disclosureButton: UIButton = {
		let button = NonIntrinsicButton()
		button.tintColor = AppAssets.secondaryAccentColor
		button.setImage(AppAssets.disclosureImage(size: 14, weight: .bold), for: .normal)
		button.contentMode = .center
		button.addInteraction(UIPointerInteraction())
		button.addTarget(self, action: #selector(toggleDisclosure), for: .touchUpInside)
		return button
	}()

	private let topSeparatorView: UIView = {
		let view = UIView()
		view.backgroundColor = UIColor.clear
		return view
	}()
	
	private let bottomSeparatorView: UIView = {
		let view = UIView()
		view.backgroundColor = UIColor.clear
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
		let layout = MasterFeedTableViewSectionHeaderLayout(cellWidth: size.width, insets: safeAreaInsets, label: titleView)
		return CGSize(width: bounds.width, height: layout.height)
		
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		let layout = MasterFeedTableViewSectionHeaderLayout(cellWidth: contentView.bounds.size.width,
															insets: contentView.safeAreaInsets,
															label: titleView)
		layoutWith(layout)
	}

}

private extension MasterFeedTableViewSectionHeader {
	
	@objc func toggleDisclosure() {
		delegate?.masterFeedTableViewSectionHeaderDisclosureDidToggle(self)
	}
	
	func commonInit() {
		addSubviewAtInit(titleView)
		addSubviewAtInit(disclosureButton)
		updateExpandedState(animate: false)
		addBackgroundView()
		addSubviewAtInit(topSeparatorView)
		addSubviewAtInit(bottomSeparatorView)
	}
	
	func updateExpandedState(animate: Bool) {
		if !isLastSection && self.disclosureExpanded {
			self.bottomSeparatorView.isHidden = false
		}
		
		let duration = animate ? 0.3 : 0.0
		
		UIView.animate(
			withDuration: duration,
			animations: {
				if self.disclosureExpanded {
					self.disclosureButton.transform = CGAffineTransform(rotationAngle: 1.570796)
				} else {
					self.disclosureButton.transform = CGAffineTransform(rotationAngle: 0)
				}
			}, completion: { _ in
				if !self.isLastSection && !self.disclosureExpanded {
					self.bottomSeparatorView.isHidden = true
				}
			})
	}

	func addSubviewAtInit(_ view: UIView) {
		contentView.addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
	}
	
	func layoutWith(_ layout: MasterFeedTableViewSectionHeaderLayout) {
		titleView.setFrameIfNotEqual(layout.titleRect)
		disclosureButton.setFrameIfNotEqual(layout.disclosureButtonRect)
		
		let top = CGRect(x: safeAreaInsets.left, y: 0, width: frame.width - safeAreaInsets.right - safeAreaInsets.left, height: 0.33)
		topSeparatorView.setFrameIfNotEqual(top)
		let bottom = CGRect(x: safeAreaInsets.left, y: frame.height - 0.33, width: frame.width - safeAreaInsets.right - safeAreaInsets.left, height: 0.33)
		bottomSeparatorView.setFrameIfNotEqual(bottom)
	}
	
	func addBackgroundView() {
		self.backgroundView = UIView(frame: self.bounds)
		self.backgroundView?.backgroundColor = .clear
	}
	
}

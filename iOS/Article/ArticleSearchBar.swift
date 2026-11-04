//
//  ArticleSearchBar.swift
//  NetNewsWire
//
//  Created by Brian Sanders on 5/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

@objc @MainActor protocol SearchBarDelegate: NSObjectProtocol {
	@objc optional func nextWasPressed(_ searchBar: ArticleSearchBar)
	@objc optional func previousWasPressed(_ searchBar: ArticleSearchBar)
	@objc optional func doneWasPressed(_ searchBar: ArticleSearchBar)
	@objc optional func searchBar(_ searchBar: ArticleSearchBar, textDidChange: String)
}

@IBDesignable final class ArticleSearchBar: UIStackView {
	var searchField: UISearchTextField!
	var nextButton: UIButton!
	var prevButton: UIButton!
	var shouldBeginEditing: Bool = true

	weak private var resultsLabel: UILabel!

	private static let margins = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
	private static let controlHeight: CGFloat = 44
	private static let controlSpacing: CGFloat = 8
	private static let minimumHeight = controlHeight + margins.top + margins.bottom
	private static let capsuleCornerRadius = controlHeight / 2
	private static let searchFieldInset: CGFloat = 8
	private static let previousNextWidth: CGFloat = 96

	var resultsCount: UInt = 0 {
		didSet {
			updateUI()
		}
	}
	var selectedResult: UInt = 1 {
		didSet {
			updateUI()
		}
	}

	weak var delegate: SearchBarDelegate?

	override var keyCommands: [UIKeyCommand]? {
		return [UIKeyCommand(title: "Exit Find", action: #selector(donePressed(_:)), input: UIKeyCommand.inputEscape)]
	}

	override var intrinsicContentSize: CGSize {
		let contentSize = super.intrinsicContentSize
		return CGSize(width: contentSize.width, height: max(Self.minimumHeight, contentSize.height))
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}

	required init(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	override func didMoveToSuperview() {
		super.didMoveToSuperview()
		layer.backgroundColor = UIColor.clear.cgColor
		isOpaque = false
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: searchField)
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		updateMarginsForReservedRegions()
	}

	private func updateUI() {
		if resultsCount > 0 {
			let format = NSLocalizedString("%d of %d", comment: "Results selection and count")
			resultsLabel.text = String.localizedStringWithFormat(format, selectedResult, resultsCount)
		} else {
			resultsLabel.text = NSLocalizedString("No results", comment: "No results")
		}

		nextButton.isEnabled = selectedResult < resultsCount
		prevButton.isEnabled = resultsCount > 0 && selectedResult > 1
	}

	@discardableResult override func becomeFirstResponder() -> Bool {
		searchField.becomeFirstResponder()
	}

	@discardableResult override func resignFirstResponder() -> Bool {
		searchField.resignFirstResponder()
	}

	override var isFirstResponder: Bool {
		searchField.isFirstResponder
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}

private extension ArticleSearchBar {
	func updateMarginsForReservedRegions() {
		// The fold is a physical feature, so these are left and right, not leading and trailing.
		var margins = Self.margins

		#if compiler(>=6.4)
		// This stops Xcode 26 having a hissy.
		if #available(iOS 27.1, *),
		   let division = reservedRegions(kind: .division).first(where: { region in
			   region.frame.intersects(bounds) && region.frame.height > region.frame.width
		   }) {
			let leftWidth = division.frame.minX - bounds.minX
			let rightWidth = bounds.maxX - division.frame.maxX
			if leftWidth >= rightWidth {
				margins.right = bounds.maxX - division.frame.minX + Self.controlSpacing
			} else {
				margins.left = division.frame.maxX - bounds.minX + Self.controlSpacing
			}
		}
		#endif

		if layoutMargins != margins {
			layoutMargins = margins
		}
	}

	func commonInit() {
		isLayoutMarginsRelativeArrangement = true
		alignment = .center
		spacing = Self.controlSpacing
		layoutMargins = Self.margins

		var doneConfiguration: UIButton.Configuration
		#if compiler(>=6.4)
		if #available(iOS 27, *) {
			doneConfiguration = .glass()
		} else {
			doneConfiguration = .tinted()
		}
		#else
		doneConfiguration = .tinted()
		#endif
		doneConfiguration.image = UIImage(systemName: "xmark")
		doneConfiguration.buttonSize = .medium
		doneConfiguration.cornerStyle = .capsule
		let doneButton = UIButton(configuration: doneConfiguration)
		doneButton.accessibilityLabel = NSLocalizedString("Done", comment: "Done")
		doneButton.isAccessibilityElement = true
		doneButton.addTarget(self, action: #selector(donePressed), for: .touchUpInside)
		doneButton.isEnabled = true
		doneButton.heightAnchor.constraint(equalToConstant: Self.controlHeight).isActive = true
		doneButton.widthAnchor.constraint(equalTo: doneButton.heightAnchor).isActive = true
		addArrangedSubview(doneButton)

		let resultsLabel = UILabel()
		searchField = UISearchTextField()
		searchField.autocapitalizationType = .none
		searchField.autocorrectionType = .no
		searchField.returnKeyType = .search
		searchField.delegate = self
		searchField.placeholder = NSLocalizedString("Find in Article", comment: "Find in Article")
		searchField.backgroundColor = .clear
		searchField.borderStyle = .none

		resultsLabel.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
		resultsLabel.textColor = .secondaryLabel
		resultsLabel.text = ""
		resultsLabel.textAlignment = .right
		resultsLabel.adjustsFontSizeToFitWidth = true
		searchField.rightView = resultsLabel
		searchField.rightViewMode = .always

		self.resultsLabel = resultsLabel
		addCapsule(containing: searchField, horizontalInset: Self.searchFieldInset)

		var previousConfiguration = UIButton.Configuration.plain()
		previousConfiguration.image = UIImage(systemName: "chevron.up")
		previousConfiguration.buttonSize = .medium
		prevButton = UIButton(configuration: previousConfiguration)
		prevButton.accessibilityLabel = "Previous Result"
		prevButton.isAccessibilityElement = true
		prevButton.addTarget(self, action: #selector(previousPressed), for: .touchUpInside)

		var nextConfiguration = UIButton.Configuration.plain()
		nextConfiguration.image = UIImage(systemName: "chevron.down")
		nextConfiguration.buttonSize = .medium
		nextButton = UIButton(configuration: nextConfiguration)
		nextButton.accessibilityLabel = "Next Result"
		nextButton.isAccessibilityElement = true
		nextButton.addTarget(self, action: #selector(nextPressed), for: .touchUpInside)

		let navigationStack = UIStackView(arrangedSubviews: [prevButton, nextButton])
		navigationStack.axis = .horizontal
		navigationStack.distribution = .fillEqually
		let navigationCapsule = addCapsule(containing: navigationStack, horizontalInset: 0)
		navigationCapsule.widthAnchor.constraint(equalToConstant: Self.previousNextWidth).isActive = true
	}

	/// Adds a blurred, capsule-shaped background holding `content` as an arranged subview.
	@discardableResult func addCapsule(containing content: UIView, horizontalInset: CGFloat) -> UIVisualEffectView {
		let capsule = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
		capsule.clipsToBounds = true
		capsule.layer.cornerCurve = .continuous
		capsule.layer.cornerRadius = Self.capsuleCornerRadius
		content.translatesAutoresizingMaskIntoConstraints = false
		capsule.contentView.addSubview(content)
		addArrangedSubview(capsule)
		NSLayoutConstraint.activate([
			capsule.heightAnchor.constraint(equalToConstant: Self.controlHeight),
			content.leadingAnchor.constraint(equalTo: capsule.contentView.leadingAnchor, constant: horizontalInset),
			content.trailingAnchor.constraint(equalTo: capsule.contentView.trailingAnchor, constant: -horizontalInset),
			content.topAnchor.constraint(equalTo: capsule.contentView.topAnchor),
			content.bottomAnchor.constraint(equalTo: capsule.contentView.bottomAnchor)
		])
		return capsule
	}
}

private extension ArticleSearchBar {

	@objc func textDidChange(_ notification: Notification) {
		delegate?.searchBar?(self, textDidChange: searchField.text ?? "")

		if searchField.text?.isEmpty ?? true {
			searchField.rightViewMode = .never
		} else {
			searchField.rightViewMode = .always
		}
	}

	@objc func nextPressed() {
		delegate?.nextWasPressed?(self)
	}

	@objc func previousPressed() {
		delegate?.previousWasPressed?(self)
	}

	@objc func donePressed(_ _: Any? = nil) {
		delegate?.doneWasPressed?(self)
	}
}

extension ArticleSearchBar: UITextFieldDelegate {
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		delegate?.nextWasPressed?(self)
		return false
	}

	func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
		return shouldBeginEditing
	}
}

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
	var background: UIView!
	var shouldBeginEditing: Bool = true

	weak private var resultsLabel: UILabel!

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
		return CGSize(width: contentSize.width, height: max(56, contentSize.height))
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
		var margins = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)

		if #available(iOS 27.1, *),
		   let division = reservedRegions(kind: .division).first(where: { region in
			   region.frame.intersects(bounds) && region.frame.height > region.frame.width
		   }) {
			let leadingWidth = division.frame.minX - bounds.minX
			let trailingWidth = bounds.maxX - division.frame.maxX
			if leadingWidth >= trailingWidth {
				margins.trailing = bounds.maxX - division.frame.minX + 8
			} else {
				margins.leading = division.frame.maxX - bounds.minX + 8
			}
		}

		if directionalLayoutMargins != margins {
			directionalLayoutMargins = margins
		}
	}

	func commonInit() {
		isLayoutMarginsRelativeArrangement = true
		alignment = .center
		spacing = 8
		directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)

		let background = UIView(frame: bounds)
		background.backgroundColor = .clear
		background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		self.background = background
		addSubview(background)

		var doneConfiguration: UIButton.Configuration
		if #available(iOS 27, *) {
			doneConfiguration = .glass()
		} else {
			doneConfiguration = .tinted()
		}
		doneConfiguration.image = UIImage(systemName: "xmark")
		doneConfiguration.buttonSize = .medium
		doneConfiguration.cornerStyle = .capsule
		let doneButton = UIButton(configuration: doneConfiguration)
		doneButton.accessibilityLabel = NSLocalizedString("Done", comment: "Done")
		doneButton.isAccessibilityElement = true
		doneButton.addTarget(self, action: #selector(donePressed), for: .touchUpInside)
		doneButton.isEnabled = true
		doneButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
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
		let searchBackground = UIVisualEffectView(effect: searchBarVisualEffect())
		searchBackground.clipsToBounds = true
		searchBackground.layer.cornerCurve = .continuous
		searchBackground.layer.cornerRadius = 22
		searchField.translatesAutoresizingMaskIntoConstraints = false
		searchBackground.contentView.addSubview(searchField)
		addArrangedSubview(searchBackground)
		NSLayoutConstraint.activate([
			searchBackground.heightAnchor.constraint(equalToConstant: 44),
			searchField.leadingAnchor.constraint(equalTo: searchBackground.contentView.leadingAnchor, constant: 8),
			searchField.trailingAnchor.constraint(equalTo: searchBackground.contentView.trailingAnchor, constant: -8),
			searchField.topAnchor.constraint(equalTo: searchBackground.contentView.topAnchor),
			searchField.bottomAnchor.constraint(equalTo: searchBackground.contentView.bottomAnchor)
		])

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
		let navigationBackground = UIVisualEffectView(effect: searchBarVisualEffect())
		navigationBackground.clipsToBounds = true
		navigationBackground.layer.cornerCurve = .continuous
		navigationBackground.layer.cornerRadius = 22
		navigationStack.translatesAutoresizingMaskIntoConstraints = false
		navigationBackground.contentView.addSubview(navigationStack)
		addArrangedSubview(navigationBackground)
		NSLayoutConstraint.activate([
			navigationStack.leadingAnchor.constraint(equalTo: navigationBackground.contentView.leadingAnchor),
			navigationStack.trailingAnchor.constraint(equalTo: navigationBackground.contentView.trailingAnchor),
			navigationStack.topAnchor.constraint(equalTo: navigationBackground.contentView.topAnchor),
			navigationStack.bottomAnchor.constraint(equalTo: navigationBackground.contentView.bottomAnchor),
			navigationBackground.heightAnchor.constraint(equalToConstant: 44),
			navigationBackground.widthAnchor.constraint(equalToConstant: 96)
		])
	}

	func searchBarVisualEffect() -> UIVisualEffect {
		return UIBlurEffect(style: .systemChromeMaterial)
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

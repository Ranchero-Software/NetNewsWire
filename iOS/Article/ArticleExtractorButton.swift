//
//  ArticleExtractorButton.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

enum ArticleExtractorButtonState {
	case error
	case animated
	case on
	case off
}

final class ArticleExtractorButton: UIButton {

	private let activityIndicator: UIActivityIndicatorView = {
		let indicator = UIActivityIndicatorView(style: .medium)
		indicator.hidesWhenStopped = true
		indicator.translatesAutoresizingMaskIntoConstraints = false
		return indicator
	}()

	var buttonState: ArticleExtractorButtonState = .off {
		didSet {
			if buttonState != oldValue {
				switch buttonState {
				case .error:
					activityIndicator.stopAnimating()
					isUserInteractionEnabled = true
					setImage(Assets.Images.articleExtractorError, for: .normal)
				case .animated:
					setImage(nil, for: .normal)
					activityIndicator.startAnimating()
					isUserInteractionEnabled = false
				case .on:
					activityIndicator.stopAnimating()
					isUserInteractionEnabled = true
					setImage(Assets.Images.articleExtractorOn, for: .normal)
				case .off:
					activityIndicator.stopAnimating()
					isUserInteractionEnabled = true
					setImage(Assets.Images.articleExtractorOff, for: .normal)
				}
			}
		}
	}

	override var accessibilityLabel: String? {
		get {
			switch buttonState {
			case .error:
				return NSLocalizedString("Error - Reader View", comment: "Error - Reader View")
			case .animated:
				return NSLocalizedString("Processing - Reader View", comment: "Processing - Reader View")
			case .on:
				return NSLocalizedString("Selected - Reader View", comment: "Selected - Reader View")
			case .off:
				return NSLocalizedString("Reader View", comment: "Reader View")
			}
		}
		set {
			super.accessibilityLabel = newValue
		}
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	private func commonInit() {
		addSubview(activityIndicator)
		NSLayoutConstraint.activate([
			activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
			activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
		])
	}
}

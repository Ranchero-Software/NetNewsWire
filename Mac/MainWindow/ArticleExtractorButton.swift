//
//  ArticleExtractorButton.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 8/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit

enum ArticleExtractorButtonState {
	case error
	case animated
	case on
	case off
}

final class ArticleExtractorButton: NSButton {

	private let progressIndicator: NSProgressIndicator = {
		let indicator = NSProgressIndicator()
		indicator.style = .spinning
		indicator.controlSize = .small
		indicator.isDisplayedWhenStopped = false
		indicator.translatesAutoresizingMaskIntoConstraints = false
		return indicator
	}()

	var buttonState: ArticleExtractorButtonState = .off {
		didSet {
			if buttonState != oldValue {
				switch buttonState {
				case .error:
					progressIndicator.stopAnimation(nil)
					isEnabled = true
					image = Assets.Images.articleExtractorError
				case .animated:
					image = nil
					progressIndicator.startAnimation(nil)
					isEnabled = false
				case .on:
					progressIndicator.stopAnimation(nil)
					isEnabled = true
					image = Assets.Images.articleExtractorOn
				case .off:
					progressIndicator.stopAnimation(nil)
					isEnabled = true
					image = Assets.Images.articleExtractorOff
				}
			}
		}
	}

	override func accessibilityLabel() -> String? {
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

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	private func commonInit() {
		wantsLayer = true
		bezelStyle = .texturedRounded
		image = Assets.Images.articleExtractorOff
		imageScaling = .scaleProportionallyDown
		widthAnchor.constraint(equalTo: heightAnchor).isActive = true

		addSubview(progressIndicator)
		NSLayoutConstraint.activate([
			progressIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
			progressIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
		])
	}
}

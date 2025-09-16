//
//  InteractiveLabel.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/3/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

@IBDesignable
final class InteractiveLabel: UILabel, UIEditMenuInteractionDelegate {

	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	func commonInit() {
		let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture(_:)))
		self.addGestureRecognizer(gestureRecognizer)

		let editMenuInteraction = UIEditMenuInteraction(delegate: self)
		addInteraction(editMenuInteraction)

		self.isUserInteractionEnabled = true
	}

	@objc func handleLongPressGesture(_ recognizer: UIGestureRecognizer) {
		guard recognizer.state == .began, let recognizerView = recognizer.view else {
			return
		}

		if let interaction = recognizerView.interactions.first(where: { $0 is UIEditMenuInteraction }) as? UIEditMenuInteraction {
			let location = recognizer.location(in: recognizerView)
			let editMenuConfiguration = UIEditMenuConfiguration(identifier: nil, sourcePoint: location)
			interaction.presentEditMenu(with: editMenuConfiguration)
		}
	}

	override var canBecomeFirstResponder: Bool {
		return true
	}

	override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
		return (action == #selector(UIResponderStandardEditActions.copy(_:)))
	}

	override func copy(_ sender: Any?) {
		UIPasteboard.general.string = text
	}

	// MARK: - UIEditMenuInteractionDelegate

	func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {

		let copyAction = UIAction(title: "Copy", image: nil) { [weak self] action in
			self?.copy(nil)
		}
		return UIMenu(title: "", children: [copyAction])
	}
}


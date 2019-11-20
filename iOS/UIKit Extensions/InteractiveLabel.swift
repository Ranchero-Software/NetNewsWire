//
//  InteractiveLabel.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/3/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

@IBDesignable
class InteractiveLabel: UILabel {

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
		self.isUserInteractionEnabled = true
	}

	@objc func handleLongPressGesture(_ recognizer: UIGestureRecognizer) {
		guard recognizer.state == .began,
			let recognizerView = recognizer.view,
			let recognizerSuperView = recognizerView.superview,
			recognizerView.becomeFirstResponder() else {
				return
		}
		
		UIMenuController.shared.showMenu(from: recognizerSuperView, rect: recognizerView.frame)
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
	
}

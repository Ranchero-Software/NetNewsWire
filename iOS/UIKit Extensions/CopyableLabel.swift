//
//  CopyableLabel.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 10/20/26.
//

import UIKit
import SwiftUI

/// A label that shows a Copy edit menu on long press. Copy copies the entire text — no selection.
final class CopyableLabel: UILabel {

	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
}

// MARK: - UIEditMenuInteractionDelegate

extension CopyableLabel: @preconcurrency UIEditMenuInteractionDelegate {

	func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
		let title = NSLocalizedString("Copy", comment: "Command")
		let copyAction = UIAction(title: title) { [weak self] _ in
			UIPasteboard.general.string = self?.text
		}
		return UIMenu(children: [copyAction])
	}
}

// MARK: - Private

private extension CopyableLabel {

	func commonInit() {
		isUserInteractionEnabled = true
		addInteraction(UIEditMenuInteraction(delegate: self))
		addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(showEditMenu(_:))))
	}

	@objc func showEditMenu(_ recognizer: UILongPressGestureRecognizer) {
		guard recognizer.state == .began else {
			return
		}
		guard let editMenuInteraction = interactions.first(where: { $0 is UIEditMenuInteraction }) as? UIEditMenuInteraction else {
			return
		}
		let sourcePoint = CGPoint(x: bounds.midX, y: bounds.minY)
		editMenuInteraction.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: sourcePoint))
	}
}

// MARK: - SwiftUI

/// SwiftUI wrapper for `CopyableLabel`. Defaults to centered, secondary-colored body text.
struct CopyableText: UIViewRepresentable {

	let text: String
	let font: UIFont
	let textColor: UIColor
	let textAlignment: NSTextAlignment

	init(text: String, font: UIFont = UIFont.preferredFont(forTextStyle: .body), textColor: UIColor = UIColor.secondaryLabel, textAlignment: NSTextAlignment = .center) {
		self.text = text
		self.font = font
		self.textColor = textColor
		self.textAlignment = textAlignment
	}

	func makeUIView(context: Context) -> CopyableLabel {
		let label = CopyableLabel()
		label.font = font
		label.adjustsFontForContentSizeCategory = true
		label.textColor = textColor
		label.textAlignment = textAlignment
		label.numberOfLines = 0
		return label
	}

	func updateUIView(_ label: CopyableLabel, context: Context) {
		label.text = text
	}

	func sizeThatFits(_ proposal: ProposedViewSize, uiView label: CopyableLabel, context: Context) -> CGSize? {
		let width = proposal.width ?? CGFloat.greatestFiniteMagnitude
		return label.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
	}
}

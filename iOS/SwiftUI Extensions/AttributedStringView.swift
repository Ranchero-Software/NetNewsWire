//
//  AttributedStringView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI

struct AttributedStringView: UIViewRepresentable {
	
	let string: NSAttributedString
	let preferredMaxLayoutWidth: CGFloat
	
    func makeUIView(context: Context) -> HackedTextView {
		return HackedTextView()
    }

    func updateUIView(_ view: HackedTextView, context: Context) {
		view.attributedText = string
		
		view.preferredMaxLayoutWidth = preferredMaxLayoutWidth
		view.isScrollEnabled = false
		view.textContainer.lineBreakMode = .byWordWrapping
		
		view.isUserInteractionEnabled = true
		view.adjustsFontForContentSizeCategory = true
		view.font = .preferredFont(forTextStyle: .body)
		view.textColor = UIColor.label
		view.tintColor = AppAssets.secondaryAccentColor
		view.backgroundColor = UIColor.secondarySystemGroupedBackground

        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
	}
	
}

class HackedTextView: UITextView {
	var preferredMaxLayoutWidth = CGFloat.zero
	override var intrinsicContentSize: CGSize {
		return sizeThatFits(CGSize(width: preferredMaxLayoutWidth, height: .infinity))
	}
}

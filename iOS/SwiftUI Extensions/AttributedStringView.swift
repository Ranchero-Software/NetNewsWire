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
	
    func makeUIView(context: Context) -> UILabel {
		return UILabel()
    }

    func updateUIView(_ view: UILabel, context: Context) {
		view.attributedText = string
		
		view.numberOfLines = 0
		view.lineBreakMode = .byWordWrapping
		view.preferredMaxLayoutWidth = preferredMaxLayoutWidth

		view.adjustsFontForContentSizeCategory = true
		view.font = .preferredFont(forTextStyle: .body)
		view.textColor = UIColor.label
		view.tintColor = AppAssets.secondaryAccentColor
		view.backgroundColor = UIColor.secondarySystemGroupedBackground

        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
	}
	
}

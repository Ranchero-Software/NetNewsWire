//
//  SettingsAttributedStringView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SettingsAttributedStringView: UIViewRepresentable {
	
	let string: NSAttributedString
	
    func makeUIView(context: Context) -> UITextView {
		let textView = UITextView()
		
		textView.attributedText = string
		textView.translatesAutoresizingMaskIntoConstraints = false
		textView.isEditable = false

		textView.adjustsFontForContentSizeCategory = true
		textView.font = .preferredFont(forTextStyle: .body)
		textView.textColor = UIColor.label
		textView.tintColor = AppAssets.secondaryAccentColor
		textView.backgroundColor = UIColor.secondarySystemGroupedBackground
		
		return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
	}
	
}

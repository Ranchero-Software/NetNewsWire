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
		
		textView.adjustsFontForContentSizeCategory = true
		textView.font = .preferredFont(forTextStyle: .body)
		textView.textColor = UIColor.label
		textView.backgroundColor = UIColor.secondarySystemGroupedBackground
		
		textView.isEditable = false
		textView.isSelectable = false
		
		return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
	}
	
}

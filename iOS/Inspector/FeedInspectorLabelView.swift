//
//  FeedInspectorLabel.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/3/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI

struct FeedInspectorLabelView : UIViewRepresentable {
 
	let text: String
	
    func makeUIView(context: Context) -> InteractiveLabel {
		return InteractiveLabel()
    }
 
    func updateUIView(_ label: InteractiveLabel, context: Context) {
		label.text = text
    }
 
}

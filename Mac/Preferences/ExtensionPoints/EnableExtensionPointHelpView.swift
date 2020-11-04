//
//  EnableExtensionPointHelpView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 4/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import SwiftUI
import RSCore

struct EnableExtensionPointHelpView: View {
	let imageLiterals = ["extensionPointMarsEdit", "extensionPointMicroblog", "extensionPointReddit", "extensionPointTwitter"]
	var helpText: String
	weak var preferencesController: ExtensionPointPreferencesViewController?
	
	@State private var hoveringId: String?
	
	var body: some View {
		VStack {
			HStack {
				ForEach(imageLiterals, id: \.self) { name in
					Image(name)
						.resizable()
						.frame(width: 20, height: 20, alignment: .center)
						.onTapGesture {
							preferencesController?.enableExtensionPoints(self)
							hoveringId = nil
						}
						.onHover(perform: { hovering in
							if hovering {
								hoveringId = name
							} else {
								hoveringId = nil
							}
						})
						.scaleEffect(hoveringId == name ? 1.2 : 1)
						.shadow(radius: hoveringId == name ? 0.8 : 0)
				}
			}
			
			Text(helpText)
				.multilineTextAlignment(.center)
				.padding(.top, 8)
		}
	}
}

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

	var extensionPoints: [ExtensionPoint.Type] {
		let types = ExtensionPointManager.shared.availableExtensionPointTypes.filter({ $0 is SendToCommand.Type }) +
			ExtensionPointManager.shared.availableExtensionPointTypes.filter({ !($0 is SendToCommand.Type) })
		return types
	}
	var helpText: String
	weak var preferencesController: ExtensionPointPreferencesViewController?
	
	var body: some View {
		VStack {
			HStack {
				ForEach(0..<extensionPoints.count, content: { i in
					Button(action: {
						preferencesController?.enableExtensionPointFromSelection(extensionPoints[i])
					}, label: {
						Image(nsImage: extensionPoints[i].image)
							.resizable()
							.frame(width: 20, height: 20, alignment: .center)
					})
					.buttonStyle(PlainButtonStyle())
				})
				
				if ExtensionPointManager.shared.availableExtensionPointTypes.count == 0 {
					Image("markUnread")
						.resizable()
						.renderingMode(.template)
						.frame(width: 30, height: 30, alignment: .center)
						.foregroundColor(.green)
				}
			}
			
			Text(helpText)
				.multilineTextAlignment(.center)
				.padding(.top, 8)
		}
	}
}

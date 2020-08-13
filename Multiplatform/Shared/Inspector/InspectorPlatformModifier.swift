//
//  InspectorPlatformModifier.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 18/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct InspectorPlatformModifier: ViewModifier {
	
	@Environment(\.presentationMode) var presentationMode
	@Binding var shouldUpdate: Bool
	
	@ViewBuilder func body(content: Content) -> some View {
		
		#if os(macOS)
		content
		.textFieldStyle(RoundedBorderTextFieldStyle())
		.frame(width: 300)
		.padding()
		#else
		NavigationView {
			content
			.listStyle(InsetGroupedListStyle())
			.navigationBarTitle("Inspector", displayMode: .inline)
			.navigationBarItems(
				leading:
				Button("Cancel", action: {
					presentationMode.wrappedValue.dismiss()
				}),
				trailing:
				Button("Done", action: {
					shouldUpdate = true
				})
			)
		}
		#endif
	}
	
	
}

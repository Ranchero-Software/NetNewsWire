//
//  ExtensionSectionHeader.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 19/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct ExtensionSectionHeader: View {
	
	var extensionPoint: ExtensionPoint.Type
	
	var body: some View {
		Section(header: headerImage) {}
	}
	
	var headerImage: some View {
		HStack {
			Spacer()
			Image(uiImage: extensionPoint.image)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 48, height: 48)
			Spacer()
		}
	}
}

//
//  AddExtensionListView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 13/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Accounts

struct AddExtensionListView: View {
	
	@State private var availableExtensionPointTypes = ExtensionPointManager.shared.availableExtensionPointTypes.sorted(by: { $0.title < $1.title })
	@Environment(\.dismiss) var dismiss
	
	var body: some View {
		NavigationView {
			List {
				Section(header: Text("FEED_PROVIDER_HEADER", tableName: "Settings"),
						footer: Text("FEED_PROVIDER_FOOTER", tableName: "Settings")) {
					ForEach(0..<availableExtensionPointTypes.count, id: \.self) { i in
						NavigationLink {
							EnableExtensionPointView(extensionPoint: availableExtensionPointTypes[i])
						} label: {
							Image(uiImage: availableExtensionPointTypes[i].image)
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(width: 25, height: 25)
							
							Text("\(availableExtensionPointTypes[i].title)")
						}
					}
				}
			}
			.navigationBarTitleDisplayMode(.inline)
			.navigationTitle(Text("ADD_EXTENSIONS_TITLE", tableName: "Settings"))
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button(role: .cancel) {
						dismiss()
					} label: {
						Text("CANCEL_BUTTON_TITLE", tableName: "Buttons")
					}
				}
			}
			.onReceive(NotificationCenter.default.publisher(for: .ActiveExtensionPointsDidChange)) { _ in
				dismiss()
			}
		}
		
	}
}

struct AddExtensionListView_Previews: PreviewProvider {
	static var previews: some View {
		AddExtensionListView()
	}
}

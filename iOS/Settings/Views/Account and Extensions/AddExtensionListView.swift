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
				Section(header: Text("Feed Provider"),footer: Text("Feed Providers allow you to subscribe to some pages as if they were RSS Feeds.")) {
					ForEach(0..<availableExtensionPointTypes.count, id: \.self) { i in
						NavigationLink {
							EnableExtensionPointViewWrapper(extensionPoint: availableExtensionPointTypes[i])
								.edgesIgnoringSafeArea(.all)
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
			.navigationTitle("Add Extension")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						dismiss()
					} label: {
						Text("Done")
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

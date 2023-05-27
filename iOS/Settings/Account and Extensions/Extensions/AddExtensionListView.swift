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
	@State private var showExtensionPointView: (ExtensionPoint.Type?, Bool) = (nil, false)
	
	var body: some View {
		NavigationView {
			List {
				Section(header: Text("Feed Providers", comment: "Feed Providers section header"),
						footer: Text("Feed Providers allow you to subscribe to some pages as if they were RSS feeds.", comment: "Feed Providers section footer.")) {
					ForEach(0..<availableExtensionPointTypes.count, id: \.self) { i in
						Button {
							showExtensionPointView = (availableExtensionPointTypes[i], true)
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
			.navigationTitle(Text("Add Extensions", comment: "Navigation title: Add Extensions"))
			.sheet(isPresented: $showExtensionPointView.1, content: {
				if showExtensionPointView.0 != nil {
					EnableExtensionPointView(extensionPoint: showExtensionPointView.0!)
				}
			})
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button(role: .cancel) {
						dismiss()
					} label: {
						Text("Cancel", comment: "Button title")
					}
				}
			}
			.onReceive(NotificationCenter.default.publisher(for: .ActiveExtensionPointsDidChange), perform: { _ in
				dismiss()
			})
		}
		
	}
}

struct AddExtensionListView_Previews: PreviewProvider {
	static var previews: some View {
		AddExtensionListView()
	}
}

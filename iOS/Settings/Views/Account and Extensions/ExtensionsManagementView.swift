//
//  ExtensionsManagementView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 30/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct ExtensionsManagementView: View {
    
	@State private var availableExtensionPointTypes = ExtensionPointManager.shared.availableExtensionPointTypes.sorted(by: { $0.title < $1.title })
	
	var body: some View {
		List {
			Section(header: Text("Add Extension"), footer: Text("Extensions allow you to subscribe to some pages as if they were RSS feeds.")) {
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
			
			Section(header: Text("Active Extensions")) {
				ForEach(0..<ExtensionPointManager.shared.activeExtensionPoints.count, id: \.self) { i in
					let point = Array(ExtensionPointManager.shared.activeExtensionPoints)[i]
					NavigationLink {
						ExtensionPointInspectorWrapper(extensionPoint: point.value)
							.navigationBarTitle(Text(point.value.title))
							.edgesIgnoringSafeArea(.all)
					} label: {
						Image(uiImage: point.value.image)
							.resizable()
							.aspectRatio(contentMode: .fit)
							.frame(width: 25, height: 25)
						Text(point.value.title)
					}
				}
			}
		}
		.navigationTitle(Text("Manage Extensions"))
    }
}

struct ExtensionsManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ExtensionsManagementView()
    }
}

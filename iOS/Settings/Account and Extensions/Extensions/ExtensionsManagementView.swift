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
	@State private var showAddExtensionView: Bool = false
	@State private var showDeactivateAlert: Bool = false
	@State private var extensionToDeactivate: Dictionary<ExtensionPointIdentifer, any ExtensionPoint>.Element? = nil
	
	var body: some View {
		List {
			activeExtensionsSection
		}
		.navigationTitle(Text("Manage Extensions", comment: "Navigation title: Manage Extensions"))
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					showAddExtensionView = true
				} label: {
					Image(systemName: "plus")
				}
			}
		}
		.sheet(isPresented: $showAddExtensionView) {
			AddExtensionListView()
		}
		.alert(Text("Deactivate Extension", comment: "Alert title: confirm deactivate extension"),
			   isPresented: $showDeactivateAlert) {
			
			Button(role: .destructive) {
				ExtensionPointManager.shared.deactivateExtensionPoint(extensionToDeactivate!.value.extensionPointID)
			} label: {
				Text("Deactivate Extension", comment: "Button: deactivate extension.")
			}

			Button(role: .cancel) {
				extensionToDeactivate = nil
			} label: {
				Text("Cancel", comment: "Button title")
			}

		} message: {
			Text("Are you sure you want to deactivate the “\(extensionToDeactivate?.value.title ?? "")” extension?", comment: "Alert message: confirm deactivation of extension.")
		}
		.onReceive(NotificationCenter.default.publisher(for: .ActiveExtensionPointsDidChange)) { _ in
			availableExtensionPointTypes = ExtensionPointManager.shared.availableExtensionPointTypes.sorted(by: { $0.title < $1.title })
		}

    }
	
	private var activeExtensionsSection: some View {
		Section(header: Text("Active Extensions", comment: "Active Extensions section header")) {
			ForEach(0..<ExtensionPointManager.shared.activeExtensionPoints.count, id: \.self) { i in
				let point = Array(ExtensionPointManager.shared.activeExtensionPoints)[i]
				NavigationLink {
					ExtensionInspectorView(extensionPoint: point.value)
				} label: {
					Image(uiImage: point.value.image)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 25, height: 25)
					Text(point.value.title)
				}.swipeActions(edge: .trailing, allowsFullSwipe: false) {
					Button(role: .destructive) {
						extensionToDeactivate = point
						showDeactivateAlert = true
					} label: {
						Text("Deactivate", comment: "Button: deactivates extension")
						Image(systemName: "minus.circle")
					}.tint(.red)
				}
			}
		}
	}
	
}

struct ExtensionsManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ExtensionsManagementView()
    }
}

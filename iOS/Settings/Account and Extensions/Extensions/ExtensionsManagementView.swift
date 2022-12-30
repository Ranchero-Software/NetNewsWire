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
		.navigationTitle(Text("navigation.title.manage-extensions", comment: " Manage Extensions"))
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
		.alert(Text("alert.title.deactive-extension.\(extensionToDeactivate?.value.extensionPointID.extensionPointType.title ?? "").\(extensionToDeactivate?.value.title ?? "")", comment: "Are you sure you want to deactivate the %@ extension “%@“? Note: the ordering of the variables is "),
			   isPresented: $showDeactivateAlert) {
			
			Button(role: .destructive) {
				ExtensionPointManager.shared.deactivateExtensionPoint(extensionToDeactivate!.value.extensionPointID)
			} label: {
				Text("button.title.deactivate-extension", comment: "Deactivate Extension")
			}

			Button(role: .cancel) {
				extensionToDeactivate = nil
			} label: {
				Text("Cancel", comment: "Button title")
			}

		} message: {
			Text("alert.message.cannot-undo-action", comment: "This action cannot be undone.")
		}
		.onReceive(NotificationCenter.default.publisher(for: .ActiveExtensionPointsDidChange)) { _ in
			availableExtensionPointTypes = ExtensionPointManager.shared.availableExtensionPointTypes.sorted(by: { $0.title < $1.title })
		}

    }
	
	private var activeExtensionsSection: some View {
		Section(header: Text("label.text.active-extensions", comment: "Active Extensions")) {
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
						Text("button.title.deactivate-extension", comment: "Deactivate Extension")
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

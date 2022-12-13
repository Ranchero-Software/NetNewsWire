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
		.navigationTitle(Text("Manage Extensions"))
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
		.alert("Deactivate Extension", isPresented: $showDeactivateAlert) {
			Button("Deactivate", role: .destructive) {
				ExtensionPointManager.shared.deactivateExtensionPoint(extensionToDeactivate!.value.extensionPointID)
			}
			Button("Dismiss", role: .cancel) {
				extensionToDeactivate = nil
			}
		} message: {
			Text("Deactivate “\(extensionToDeactivate?.value.title ?? "")”?")
		}
		.onReceive(NotificationCenter.default.publisher(for: .ActiveExtensionPointsDidChange)) { _ in
			availableExtensionPointTypes = ExtensionPointManager.shared.availableExtensionPointTypes.sorted(by: { $0.title < $1.title })
		}

    }
	
	private var activeExtensionsSection: some View {
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
				}.swipeActions(edge: .trailing, allowsFullSwipe: false) {
					Button(role: .destructive) {
						extensionToDeactivate = point
						showDeactivateAlert = true
					} label: {
						Text("Deactivate")
						Image(systemName: "poweroff")
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

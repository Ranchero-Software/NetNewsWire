//
//  ExtensionInspectorView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 15/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI

struct ExtensionInspectorView: View {
    
	@Environment(\.dismiss) var dismiss
	@State private var showDeactivateConfirmation: Bool = false
	var extensionPoint: ExtensionPoint?
	
	var body: some View {
		Form {
			Section(header: extensionHeader) {}
			Section(footer:  Text(extensionPoint?.description.string ?? ""), content: {
				//
			})
			
			HStack {
				Spacer()
				Button(role: .destructive) {
					showDeactivateConfirmation = true
				} label: {
					Text("DEACTIVATE_EXTENSION_BUTTON_TITLE", tableName: "Buttons")
				}
				.confirmationDialog(Text("DEACTIVATE_EXTENSION_TITLE", tableName: "Settings") , isPresented: $showDeactivateConfirmation, titleVisibility: .visible) {
					
					Button(role: .destructive) {
						ExtensionPointManager.shared.deactivateExtensionPoint(extensionPoint!.extensionPointID)
						dismiss()
					} label: {
						Text("DEACTIVATE_EXTENSION_BUTTON_TITLE", tableName: "Buttons")
					}

					Button(role: .cancel) {
						 //
					} label: {
						Text("CANCEL_BUTTON_TITLE", tableName: "Buttons")
					}
				} message: {
					Text("DEACTIVATE_EXTENSION \(extensionPoint?.title ?? "")", tableName: "Settings")
				}
				Spacer()
			}

			
		}
		.navigationTitle(Text(extensionPoint?.title ?? ""))
		.edgesIgnoringSafeArea(.bottom)
		.dismissOnExternalContextLaunch()
    }
	
	var extensionHeader: some View {
		HStack {
			Spacer()
			Image(uiImage: extensionPoint!.image)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 48, height: 48)
			Spacer()
		}
	}
}

struct ExtensionInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        ExtensionInspectorView()
    }
}

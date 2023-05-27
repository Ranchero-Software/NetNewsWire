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
			Section(footer:  extensionExplainer, content: {
				//
			})
			
			HStack {
				Spacer()
				Button(role: .destructive) {
					showDeactivateConfirmation = true
				} label: {
					Text("button.title.deactivate-extension", comment: "Deactivate Extension")
				}
				.alert(Text("alert.title.deactivate-extension.\(extensionPoint?.title ?? "")", comment: "Are you sure you want to deactivate “%@“?"), isPresented: $showDeactivateConfirmation) {
					
					Button(role: .destructive) {
						ExtensionPointManager.shared.deactivateExtensionPoint(extensionPoint!.extensionPointID)
						dismiss()
					} label: {
						Text("button.title.deactivate-extension", comment: "Deactivate Extension")
					}

					Button(role: .cancel) {
						 //
					} label: {
						Text("button.title.cancel", comment: "Cancel")
					}
				} message: {
					Text("alert.message.cannot-undo-action", comment: "You can't undo this action.")
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
	
	var extensionExplainer: some View {
		Text(extensionPoint?.description.string ?? "")
			.multilineTextAlignment(.center)
	}
}

struct ExtensionInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        ExtensionInspectorView()
    }
}

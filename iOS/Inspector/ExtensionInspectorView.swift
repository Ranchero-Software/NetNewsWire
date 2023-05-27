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
					Text("Deactivate Extension", comment: "Button title")
				}
				.alert(Text("Are you sure you want to deactivate “\(extensionPoint?.title ?? "")?", comment: "Alert title: confirm deactivate extension") , isPresented: $showDeactivateConfirmation) {
					
					Button(role: .destructive) {
						ExtensionPointManager.shared.deactivateExtensionPoint(extensionPoint!.extensionPointID)
						dismiss()
					} label: {
						Text("Deactivate Extension", comment: "Button title")
					}

					Button(role: .cancel) {
						 //
					} label: {
						Text("Cancel", comment: "Button title")
					}
				} message: {
					Text("This action cannot be undone.", comment: "Alert message: remove account confirmation")
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

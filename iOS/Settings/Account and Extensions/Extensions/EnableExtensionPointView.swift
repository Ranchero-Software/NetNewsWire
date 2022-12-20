//
//  EnableExtensionPointView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 19/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI

struct EnableExtensionPointView: View  {
	
	@Environment(\.dismiss) var dismiss
	@StateObject private var viewModel = EnableExtensionViewModel()
	@State private var extensionError: (Error?, Bool) = (nil, false)
	var extensionPoint: ExtensionPoint.Type
	
	var body: some View {
		Form {
			ExtensionSectionHeader(extensionPoint: extensionPoint)
			Section(footer: extensionExplainer) {}
			Section { enableButton }
		}
		.alert(Text("ERROR_TITLE", tableName: "Errors"), isPresented: $extensionError.1, actions: {
			Button(action: {}, label: { Text("DISMISS_BUTTON_TITLE", tableName: "Buttons") })
		}, message: {
			Text(extensionError.0?.localizedDescription ?? "Unknown Error")
		})
		.navigationTitle(extensionPoint.title)
		.navigationBarTitleDisplayMode(.inline)
		.dismissOnExternalContextLaunch()
		.onReceive(NotificationCenter.default.publisher(for: .ActiveExtensionPointsDidChange)) { _ in
			dismiss()
		}
		.edgesIgnoringSafeArea(.bottom)
	}
	
	var extensionExplainer: some View {
		Text(extensionPoint.description.string)
			.multilineTextAlignment(.center)
	}
	
	var enableButton: some View {
		Button {
			Task {
				viewModel.configure(extensionPoint)
				do {
					try await viewModel.enableExtension()
				} catch {
					extensionError = (error, true)
				}
			}
		} label: {
			HStack {
				Spacer()
				Text("ENABLE_EXTENSION_BUTTON_TITLE", tableName: "Buttons")
				Spacer()
			}
			
		}
	}
	
	
	
	
}

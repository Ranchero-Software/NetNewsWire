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
		.alert(Text("Error", comment: "Alert title: Error"), isPresented: $extensionError.1, actions: {
		}, message: {
			Text(extensionError.0?.localizedDescription ?? "Unknown Error")
		})
		.alert(Text("Error", comment: "Alert title: Error"), isPresented: $viewModel.showExtensionError.1, actions: {
		}, message: {
			Text(viewModel.showExtensionError.0?.localizedDescription ?? "Unknown Error")
		})
		.navigationTitle(extensionPoint.title)
		.navigationBarTitleDisplayMode(.inline)
		.dismissOnExternalContextLaunch()
		.task {
			for await _ in NotificationCenter.default.notifications(named: .ActiveExtensionPointsDidChange) {
				await MainActor.run { dismiss() }
			}
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
				Text("Enable Extension", comment: "Button title")
				Spacer()
			}
			
		}
	}
	
	
	
	
}

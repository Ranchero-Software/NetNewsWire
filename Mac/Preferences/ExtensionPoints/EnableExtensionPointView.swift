//
//  EnableExtensionPointView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import SwiftUI
import RSCore


struct EnableExtensionPointView: View {
	
	weak var parent: NSHostingController<EnableExtensionPointView>? // required because presentationMode.dismiss() doesn't work
	weak var enabler: ExtensionPointPreferencesEnabler?
	@State private var extensionPointTypeName = String(describing: Self.sendToCommandExtensionPointTypes.first)
	private var selectedType: ExtensionPoint.Type?
	
	init(enabler: ExtensionPointPreferencesEnabler?, selectedType: ExtensionPoint.Type? ) {
		self.enabler = enabler
		self.selectedType = selectedType
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Choose an extension to add...")
				.font(.headline)
				.padding()
			
			feedProviderExtensionPoints
			sendToCommandExtensionPoints

			HStack(spacing: 12) {
				Spacer()
				if #available(OSX 11.0, *) {
					Button(action: {
						parent?.dismiss(nil)
					}, label: {
						Text("Cancel")
							.frame(width: 80)
					})
					.help("Cancel")
					.keyboardShortcut(.cancelAction)
					
				} else {
					Button(action: {
						parent?.dismiss(nil)
					}, label: {
						Text("Cancel")
							.frame(width: 80)
					})
					.accessibility(label: Text("Add Extension"))
				}
				if #available(OSX 11.0, *) {
					Button(action: {
						enabler?.enable(typeFromName(extensionPointTypeName))
						parent?.dismiss(nil)
					}, label: {
						Text("Continue")
							.frame(width: 80)
					})
					.help("Add Extension")
					.keyboardShortcut(.defaultAction)
					.disabled(disableContinue())
				} else {
					Button(action: {
						enabler?.enable(typeFromName(extensionPointTypeName))
						parent?.dismiss(nil)
					}, label: {
						Text("Continue")
							.frame(width: 80)
					})
					.disabled(disableContinue())
				}
			}
			.padding(.top, 12)
			.padding(.bottom, 4)
		}
		.pickerStyle(RadioGroupPickerStyle())
		.fixedSize(horizontal: false, vertical: true)
		.frame(width: 420)
		.padding()
		.onAppear {
			if selectedType != nil {
				extensionPointTypeName = String(describing: selectedType!)
			}
		}
	}
	
	var feedProviderExtensionPoints: some View {
		VStack(alignment: .leading) {
			let extensionPointTypeNames = Self.feedProviderExtensionPointTypes.map { String(describing: $0) }
			if extensionPointTypeNames.count > 0 {
				Text("Feed Provider")
					.font(.headline)
					.padding(.horizontal)

				Picker(selection: $extensionPointTypeName, label: Text(""), content: {
					ForEach(extensionPointTypeNames, id: \.self, content: { extensionPointTypeName in
						let extensionPointType = typeFromName(extensionPointTypeName)
						HStack(alignment: .center) {
							Image(nsImage: extensionPointType.image)
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(width: 25, height: 25, alignment: .center)
								.padding(.leading, 4)
							
								
							Text(extensionPointType.title)
						}
						.tag(extensionPointTypeName)
					})
				})
				.pickerStyle(RadioGroupPickerStyle())
				.offset(x: 7.5, y: 0)
				
				Text("An extension that makes websites appear to provide RSS feeds for their content.")
					.foregroundColor(.gray)
					.font(.caption)
					.padding(.horizontal)
			}
		}
		
	}

	var sendToCommandExtensionPoints: some View {
		VStack(alignment: .leading) {
			let extensionPointTypeNames = Self.sendToCommandExtensionPointTypes.map { String(describing: $0) }
			if extensionPointTypeNames.count > 0 {
				Text("Third-Party Integration")
					.font(.headline)
					.padding(.horizontal)
					.padding(.top, 8)

				Picker(selection: $extensionPointTypeName, label: Text(""), content: {
					ForEach(extensionPointTypeNames, id: \.self, content: { extensionPointTypeName in
						let extensionPointType = typeFromName(extensionPointTypeName)
						HStack(alignment: .center) {
							Image(nsImage: extensionPointType.image)
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(width: 25, height: 25, alignment: .center)
								.padding(.leading, 4)
							
								
							Text(extensionPointType.title)
						}
						.tag(extensionPointTypeName)
					})
				})
				.pickerStyle(RadioGroupPickerStyle())
				.offset(x: 7.5, y: 0)
				
				Text("An extension that enables a share menu item that passes article data to a third-party application.")
					.foregroundColor(.gray)
					.font(.caption)
					.padding(.horizontal)
			}
		}
		
	}
	
	static var sendToCommandExtensionPointTypes: [ExtensionPoint.Type] {
		return ExtensionPointManager.shared.availableExtensionPointTypes.filter({ $0 is SendToCommand.Type })
	}

	static var feedProviderExtensionPointTypes: [ExtensionPoint.Type] {
		return ExtensionPointManager.shared.availableExtensionPointTypes.filter({ !($0 is SendToCommand.Type) })
	}

	func typeFromName(_ name: String) -> ExtensionPoint.Type {
		for type in ExtensionPointManager.shared.possibleExtensionPointTypes {
			if name == String(describing: type) {
				return type
			}
		}
		fatalError()
	}
	
	func disableContinue() -> Bool {
		ExtensionPointManager.shared.availableExtensionPointTypes.count == 0
	}
}




//
//  SharingServicePickerDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore

@objc final class SharingServicePickerDelegate: NSObject, NSSharingServicePickerDelegate {
	
	private let sharingServiceDelegate: SharingServiceDelegate
	private let completion: (() -> Void)?
	
	init(_ window: NSWindow?, completion: (() -> Void)?) {
		self.sharingServiceDelegate = SharingServiceDelegate(window)
		self.completion = completion
	}
	
	func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
		let filteredServices = proposedServices.filter { $0.menuItemTitle != "NetNewsWire" }
		return filteredServices + SharingServicePickerDelegate.customSharingServices(for: items)
	}

	func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? {
		return sharingServiceDelegate
	}

	func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
		completion?()
	}
	
	static func customSharingServices(for items: [Any]) -> [NSSharingService] {
		let customServices = ExtensionPointManager.shared.activeSendToCommands.compactMap { (sendToCommand) -> NSSharingService? in

			guard let object = items.first else {
				return nil
			}
			
			guard sendToCommand.canSendObject(object, selectedText: nil) else {
				return nil
			}

			let image = sendToCommand.image ?? NSImage()
			return NSSharingService(title: sendToCommand.title, image: image, alternateImage: nil) {
				sendToCommand.sendObject(object, selectedText: nil)
			}
		}
		return customServices
	}
}



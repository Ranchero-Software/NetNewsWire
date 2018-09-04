//
//  SharingServicePickerDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

@objc final class SharingServicePickerDelegate: NSObject, NSSharingServicePickerDelegate {

	func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {

		return proposedServices + SharingServicePickerDelegate.customSharingServices(for: items)
	}

	static func customSharingServices(for items: [Any]) -> [NSSharingService] {

		let customServices = appDelegate.sendToCommands.compactMap { (sendToCommand) -> NSSharingService? in

			guard let object = items.first else {
				return nil
			}
			guard sendToCommand.canSendObject(object, selectedText: nil) else {
				return nil
			}

			let image = sendToCommand.image ?? AppImages.genericFeedImage ?? NSImage()
			return NSSharingService(title: sendToCommand.title, image: image, alternateImage: nil) {
				sendToCommand.sendObject(object, selectedText: nil)
			}
		}
		return customServices
	}
}

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
	
	init(_ window: NSWindow?) {
		sharingServiceDelegate = SharingServiceDelegate(window)
	}
	
	func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {

		return proposedServices + SharingServicePickerDelegate.customSharingServices(for: items)
		
	}

	func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? {
		return sharingServiceDelegate
	}

	private static let sendToCommands: [SendToCommand] = {
		return [SendToMicroBlogCommand(), SendToMarsEditCommand()]
	}()

	static func customSharingServices(for items: [Any]) -> [NSSharingService] {

		let customServices = sendToCommands.compactMap { (sendToCommand) -> NSSharingService? in

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

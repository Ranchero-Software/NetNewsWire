//
//  MasterFeedTableViewIdentifier.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/3/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import RSTree

final class MasterFeedTableViewIdentifier: NSObject, NSCopying {
	
	let feedID: FeedIdentifier?
	let containerID: ContainerIdentifier?
	let parentContainerID: ContainerIdentifier?

	let isEditable: Bool
	let isPsuedoFeed: Bool
	let isFolder: Bool
	let isWebFeed: Bool
	
	let nameForDisplay: String
	let url: String?
	let unreadCount: Int
	let childCount: Int
	
	init(node: Node, unreadCount: Int) {
		let feed = node.representedObject as! Feed
		self.feedID = feed.feedID
		self.containerID = (node.representedObject as? Container)?.containerID
		self.parentContainerID = (node.parent?.representedObject as? Container)?.containerID
		
		self.isEditable = !(node.representedObject is PseudoFeed)
		self.isPsuedoFeed = node.representedObject is PseudoFeed
		self.isFolder = node.representedObject is Folder
		self.isWebFeed = node.representedObject is WebFeed
		self.nameForDisplay = feed.nameForDisplay
		
		if let webFeed = node.representedObject as? WebFeed {
			self.url = webFeed.url
		} else {
			self.url = nil
		}

		self.unreadCount = unreadCount
		self.childCount = node.numberOfChildNodes
	}
		
	override func isEqual(_ object: Any?) -> Bool {
		guard let otherIdentifier = object as? MasterFeedTableViewIdentifier else { return false }
		if self === otherIdentifier { return true }
		return feedID == otherIdentifier.feedID && parentContainerID == otherIdentifier.parentContainerID
	}
	
	override var hash: Int {
		var hasher = Hasher()
		hasher.combine(feedID)
		hasher.combine(parentContainerID)
		return hasher.finalize()
	}

	func copy(with zone: NSZone? = nil) -> Any {
		return self
	}

}

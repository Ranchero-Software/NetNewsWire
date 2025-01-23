//
//  OPMLNormalizer.swift
//  Account
//
//  Created by Maurice Parker on 3/31/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Parser

final class OPMLNormalizer {

	var normalizedOPMLItems = [OPMLItem]()

	static func normalize(_ items: [OPMLItem]) -> [OPMLItem] {
		let opmlNormalizer = OPMLNormalizer()
		opmlNormalizer.normalize(items)
		return opmlNormalizer.normalizedOPMLItems
	}

	private func normalize(_ items: [OPMLItem], parentFolder: OPMLItem? = nil) {
		var feedsToAdd = [OPMLItem]()

		for item in items {

			if let _ = item.feedSpecifier {
				if !feedsToAdd.contains(where: { $0.feedSpecifier?.feedURL == item.feedSpecifier?.feedURL }) {
					feedsToAdd.append(item)
				}
				continue
			}

			guard let _ = item.titleFromAttributes else {
				// Folder doesn’t have a name, so it won’t be created, and its items will go one level up.
				if let itemChildren = item.items {
					normalize(itemChildren, parentFolder: parentFolder)
				}
				continue
			}

			feedsToAdd.append(item)
			if let itemChildren = item.items {
				if let parentFolder = parentFolder {
					normalize(itemChildren, parentFolder: parentFolder)
				} else {
					normalize(itemChildren, parentFolder: item)
				}
			}
		}

		if let parentFolder = parentFolder {
			for feed in feedsToAdd {
				if !(parentFolder.items?.contains(where: { $0.feedSpecifier?.feedURL == feed.feedSpecifier?.feedURL}) ?? false) {
					parentFolder.add(feed)
				}
			}
		} else {
			for feed in feedsToAdd {
				normalizedOPMLItems.append(feed)
			}
		}

	}

}

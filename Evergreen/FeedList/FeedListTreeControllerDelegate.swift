//
//  FeedListTreeControllerDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/4/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSTree

// Folders and feeds that appear in the Feed Directory are pulled from three sources:
// 1. Feeds added in code here. (Evergreen News should be the only one.)
// 2. Default feeds for new users — see DefaultFeeds.plist.
// 3. FeedList.plist — the main directory. Its top level is all folders. There are no sub-folders.
// It’s okay if there’s overlap: a feed may appear in multiple places.
// If there’s any problem with the data (wrong types), this will crash. By design.

final class FeedListTreeControllerDelegate: TreeControllerDelegate {

	let topLevelFeeds: Set<FeedListFeed>
	let defaultFeeds: Set<FeedListFeed>
	let folders: Set<FeedListFolder>

	init() {

		let evergreenNewsFeed = FeedListFeed(name: "Evergreen News", url: "https://ranchero.com/evergreen/feed.json", homePageURL: "https://ranchero.com/evergreen/blog/")
		self.topLevelFeeds = Set([evergreenNewsFeed])

		self.defaultFeeds = FeedListReader.defaultFeeds()
		self.folders = FeedListReader.folders()
	}

	func treeController(treeController: TreeController, childNodesFor node: Node) -> [Node]? {

//		if node.isRoot {
//			return childNodesForRootNode(node)
//		}
//		if node.representedObject is FeedListFolder {
//			return childNodesForFolderNode(node)
//		}

		return nil
	}
}



//private extension FeedListTreeControllerDelegate {
//
//	func childNodesForRootNode(_ rootNode: Node) -> [Node]? {
//
//		return childNodesForContainerNode(rootNode, AccountManager.shared.localAccount.children)
//	}
//
//}

// MARK: - Loading from Disk

private struct FeedListReader {

	static func folders() -> Set<FeedListFolder> {

		return Set(foldersDictionary().map { (arg: (key: String, value: [[String : String]])) -> FeedListFolder in

			let (name, feedDictionaries) = arg
			return FeedListFolder(name: name, feeds: feeds(with: feedDictionaries))
		})
	}

	static func defaultFeeds() -> Set<FeedListFeed> {

		return feeds(with: defaultFeedDictionaries())
	}

	private static func defaultFeedDictionaries() -> [[String: String]] {

		let f = Bundle.main.path(forResource: "DefaultFeeds", ofType: "plist")!
		return NSArray(contentsOfFile: f)! as! [[String: String]]
	}

	private static func foldersDictionary() -> [String: [[String: String]]] {

		let f = Bundle.main.path(forResource: "FeedList", ofType: "plist")!
		return NSDictionary(contentsOfFile: f)! as! [String: [[String: String]]]
	}

	private static func feeds(with dictionaries: [[String: String]]) -> Set<FeedListFeed> {

		return Set(dictionaries.map { FeedListFeed(dictionary: $0) })
	}
}


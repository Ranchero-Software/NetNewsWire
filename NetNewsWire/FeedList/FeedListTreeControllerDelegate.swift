//
//  FeedListTreeControllerDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/4/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSTree
import RSCore

// Folders and feeds that appear in the Feed Directory are pulled from three sources:
// 1. Feeds added in code here. (None, at least for now.)
// 2. Default feeds for new users — see DefaultFeeds.plist.
// 3. FeedList.plist — the main directory. Its top level is all folders. There are no sub-folders.
// It’s okay if there’s overlap: a feed may appear in multiple places.
// If there’s any problem with the data (wrong types), this will crash. By design.

final class FeedListTreeControllerDelegate: TreeControllerDelegate {

	private let topLevelFeeds: Set<FeedListFeed>
	private let folders: Set<FeedListFolder>

	init() {

//		let netnewswireNewsFeed = FeedListFeed(name: "NetNewsWire News", url: "https://nnw.ranchero.com/feed.json", homePageURL: "https://nnw.ranchero.com/")
		self.topLevelFeeds = Set<FeedListFeed>() //Set([netnewswireNewsFeedNewsFeed])

		let defaultFeeds = FeedListReader.defaultFeeds()
		let defaultFeedsFolder = FeedListFolder(name: NSLocalizedString("Default Feeds (for new users)", comment: "Feed Directory"), feeds: defaultFeeds)

		self.folders = Set(FeedListReader.folders() + [defaultFeedsFolder])
	}

	func treeController(treeController: TreeController, childNodesFor node: Node) -> [Node]? {

		if node.isRoot {
			return childNodesForRootNode(node)
		}
		return childNodesForFolderNode(node)
	}
}

// MARK: - Private

private extension FeedListTreeControllerDelegate {

	func childNodesForRootNode(_ rootNode: Node) -> [Node]? {

		let children = (Array(topLevelFeeds) as [AnyObject]) + (Array(folders) as [AnyObject])
		return childNodesForContainerNode(rootNode, children)
	}

	func childNodesForFolderNode(_ folderNode: Node) -> [Node]? {

		let folder = folderNode.representedObject as! FeedListFolder
		return childNodesForContainerNode(folderNode, Array(folder.feeds))
	}

	func childNodesForContainerNode(_ containerNode: Node, _ children: [AnyObject]) -> [Node]? {

		let nodes = unsortedNodes(parent: containerNode, children: children)
		return nodes.sortedAlphabeticallyWithFoldersAtEnd()
	}

	func unsortedNodes(parent: Node, children: [AnyObject]) -> [Node] {

		return children.map{ createNode(child: $0, parent: parent) }
	}

	func createNode(child: AnyObject, parent: Node) -> Node {

		if let feed = child as? FeedListFeed {
			return createNode(feed: feed, parent: parent)
		}
		let folder = child as! FeedListFolder
		return createNode(folder: folder, parent: parent)
	}

	func createNode(feed: FeedListFeed, parent: Node) -> Node {

		return Node(representedObject: feed, parent: parent)
	}

	func createNode(folder: FeedListFolder, parent: Node) -> Node {

		let node = Node(representedObject: folder, parent: parent)
		node.canHaveChildNodes = true
		return node
	}
}

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


//
//  MasterFeedDataSource.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 8/28/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import RSTree
import Account

class MasterFeedDataSource: UITableViewDiffableDataSource<Node, Node> {

	private var coordinator: SceneCoordinator!
	private var errorHandler: ((Error) -> ())!
	
	init(coordinator: SceneCoordinator, errorHandler: @escaping (Error) -> (), tableView: UITableView, cellProvider: @escaping UITableViewDiffableDataSource<Node, Node>.CellProvider) {
		super.init(tableView: tableView, cellProvider: cellProvider)
		self.coordinator = coordinator
		self.errorHandler = errorHandler
	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		guard let node = itemIdentifier(for: indexPath), !(node.representedObject is PseudoFeed) else {
			return false
		}
		return true
	}
	
	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		guard let node = itemIdentifier(for: indexPath) else {
			return false
		}
		return node.representedObject is Feed
	}
	
	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {

		guard let sourceNode = itemIdentifier(for: sourceIndexPath), let feed = sourceNode.representedObject as? Feed else {
			return
		}

		// Based on the drop we have to determine a node to start looking for a parent container.
		let destNode: Node = {
			if destinationIndexPath.row == 0 {
				return coordinator.rootNode.childAtIndex(destinationIndexPath.section)!
			} else {
				let movementAdjustment = sourceIndexPath > destinationIndexPath ? 1 : 0
				let adjustedDestIndexPath = IndexPath(row: destinationIndexPath.row - movementAdjustment, section: destinationIndexPath.section)
				return itemIdentifier(for: adjustedDestIndexPath)!
			}
		}()

		// Now we start looking for the parent container
		let destParentNode: Node? = {
			if destNode.representedObject is Container {
				return destNode
			} else {
				if destNode.parent?.representedObject is Container {
					return destNode.parent!
				} else {
					return nil
				}
			}
		}()
		
		// Move the Feed
		guard let source = sourceNode.parent?.representedObject as? Container, let destination = destParentNode?.representedObject as? Container else {
			return
		}
		
		if sameAccount(sourceNode, destParentNode!) {
			moveFeedInAccount(feed: feed, sourceContainer: source, destinationContainer: destination)
		} else {
			moveFeedBetweenAccounts(feed: feed, sourceContainer: source, destinationContainer: destination)
		}

	}
	
	private func sameAccount(_ node: Node, _ parentNode: Node) -> Bool {
		if let accountID = nodeAccountID(node), let parentAccountID = nodeAccountID(parentNode) {
			if accountID == parentAccountID {
				return true
			}
		}
		return false
	}
	
	private func nodeAccount(_ node: Node) -> Account? {
		if let account = node.representedObject as? Account {
			return account
		} else if let folder = node.representedObject as? Folder {
			return folder.account
		} else if let feed = node.representedObject as? Feed {
			return feed.account
		} else {
			return nil
		}

	}

	private func nodeAccountID(_ node: Node) -> String? {
		return nodeAccount(node)?.accountID
	}

	func moveFeedInAccount(feed: Feed, sourceContainer: Container, destinationContainer: Container) {
		BatchUpdate.shared.start()
		sourceContainer.account?.moveFeed(feed, from: sourceContainer, to: destinationContainer) { result in
			BatchUpdate.shared.end()
			switch result {
			case .success:
				break
			case .failure(let error):
				self.errorHandler(error)
			}
		}
	}
	
	func moveFeedBetweenAccounts(feed: Feed, sourceContainer: Container, destinationContainer: Container) {
		
		if let existingFeed = destinationContainer.account?.existingFeed(withURL: feed.url) {
			
			BatchUpdate.shared.start()
			destinationContainer.account?.addFeed(existingFeed, to: destinationContainer) { result in
				switch result {
				case .success:
					sourceContainer.account?.removeFeed(feed, from: sourceContainer) { result in
						BatchUpdate.shared.end()
						switch result {
						case .success:
							break
						case .failure(let error):
							self.errorHandler(error)
						}
					}
				case .failure(let error):
					BatchUpdate.shared.end()
					self.errorHandler(error)
				}
			}
			
		} else {
			
			BatchUpdate.shared.start()
			destinationContainer.account?.createFeed(url: feed.url, name: feed.editedName, container: destinationContainer) { result in
				switch result {
				case .success:
					sourceContainer.account?.removeFeed(feed, from: sourceContainer) { result in
						BatchUpdate.shared.end()
						switch result {
						case .success:
							break
						case .failure(let error):
							self.errorHandler(error)
						}
					}
				case .failure(let error):
					BatchUpdate.shared.end()
					self.errorHandler(error)
				}
			}
			
		}
	}

}

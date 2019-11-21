//
//  MasterFeedViewController+Drop.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Account
import RSTree

extension MasterFeedViewController: UITableViewDropDelegate {
	
	func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
		return session.localDragSession != nil //&& session.canLoadObjects(ofClass: URL.self)
	}
	
	func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
		if tableView.hasActiveDrag {
			if let destIndexPath = destinationIndexPath, let destNode = dataSource.itemIdentifier(for: destIndexPath) {
				if destNode.representedObject is Folder {
					return UITableViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
				} else {
					return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
				}
			}
		}
		return UITableViewDropProposal(operation: .forbidden)
	}
	
	func tableView(_ tableView: UITableView, performDropWith dropCoordinator: UITableViewDropCoordinator) {
		guard let dragItem = dropCoordinator.items.first?.dragItem,
			let sourceNode = dragItem.localObject as? Node,
			let sourceIndexPath = dataSource.indexPath(for: sourceNode),
			let webFeed = sourceNode.representedObject as? WebFeed,
			let destinationIndexPath = dropCoordinator.destinationIndexPath else {
				return
		}
		
		// Based on the drop we have to determine a node to start looking for a parent container.
		let destNode: Node = {
			if destinationIndexPath.row == 0 {
				return coordinator.rootNode.childAtIndex(destinationIndexPath.section)!
			} else {
				let movementAdjustment = sourceIndexPath > destinationIndexPath ? 1 : 0
				let adjustedDestIndexPath = IndexPath(row: destinationIndexPath.row - movementAdjustment, section: destinationIndexPath.section)
				return dataSource.itemIdentifier(for: adjustedDestIndexPath)!
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
		
		// Move the Web Feed
		guard let source = sourceNode.parent?.representedObject as? Container, let destination = destParentNode?.representedObject as? Container else {
			return
		}
		
		if sameAccount(sourceNode, destParentNode!) {
			moveWebFeedInAccount(feed: webFeed, sourceContainer: source, destinationContainer: destination)
		} else {
			moveWebFeedBetweenAccounts(feed: webFeed, sourceContainer: source, destinationContainer: destination)
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
		} else if let webFeed = node.representedObject as? WebFeed {
			return webFeed.account
		} else {
			return nil
		}

	}

	private func nodeAccountID(_ node: Node) -> String? {
		return nodeAccount(node)?.accountID
	}

	func moveWebFeedInAccount(feed: WebFeed, sourceContainer: Container, destinationContainer: Container) {
		BatchUpdate.shared.start()
		sourceContainer.account?.moveWebFeed(feed, from: sourceContainer, to: destinationContainer) { result in
			BatchUpdate.shared.end()
			switch result {
			case .success:
				break
			case .failure(let error):
				self.presentError(error)
			}
		}
	}
	
	func moveWebFeedBetweenAccounts(feed: WebFeed, sourceContainer: Container, destinationContainer: Container) {
		
		if let existingFeed = destinationContainer.account?.existingWebFeed(withURL: feed.url) {
			
			BatchUpdate.shared.start()
			destinationContainer.account?.addWebFeed(existingFeed, to: destinationContainer) { result in
				switch result {
				case .success:
					sourceContainer.account?.removeWebFeed(feed, from: sourceContainer) { result in
						BatchUpdate.shared.end()
						switch result {
						case .success:
							break
						case .failure(let error):
							self.presentError(error)
						}
					}
				case .failure(let error):
					BatchUpdate.shared.end()
					self.presentError(error)
				}
			}
			
		} else {
			
			BatchUpdate.shared.start()
			destinationContainer.account?.createWebFeed(url: feed.url, name: feed.editedName, container: destinationContainer) { result in
				switch result {
				case .success:
					sourceContainer.account?.removeWebFeed(feed, from: sourceContainer) { result in
						BatchUpdate.shared.end()
						switch result {
						case .success:
							break
						case .failure(let error):
							self.presentError(error)
						}
					}
				case .failure(let error):
					BatchUpdate.shared.end()
					self.presentError(error)
				}
			}
			
		}
	}


}

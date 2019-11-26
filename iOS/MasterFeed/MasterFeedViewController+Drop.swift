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
		return session.localDragSession != nil
	}
	
	func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
		guard let destIndexPath = destinationIndexPath,
			destIndexPath.section > 0,
			tableView.hasActiveDrag,
			let destNode = dataSource.itemIdentifier(for: destIndexPath),
			let destCell = tableView.cellForRow(at: destIndexPath) else {
				return UITableViewDropProposal(operation: .forbidden)
		}
		
		if destNode.representedObject is Folder {
			if session.location(in: destCell).y >= 0 {
				return UITableViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
			} else {
				return UITableViewDropProposal(operation: .move, intent: .unspecified)
			}
		} else {
			return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
		}

	}
	
	func tableView(_ tableView: UITableView, performDropWith dropCoordinator: UITableViewDropCoordinator) {
		guard let dragItem = dropCoordinator.items.first?.dragItem,
			let sourceNode = dragItem.localObject as? Node,
			let webFeed = sourceNode.representedObject as? WebFeed,
			let destIndexPath = dropCoordinator.destinationIndexPath else {
				return
		}
		
		let isFolderDrop: Bool = {
			if let propDestNode = dataSource.itemIdentifier(for: destIndexPath), let propCell = tableView.cellForRow(at: destIndexPath) {
				return propDestNode.representedObject is Folder && dropCoordinator.session.location(in: propCell).y >= 0
			}
			return false
		}()
		
		// Based on the drop we have to determine a node to start looking for a parent container.
		let destNode: Node? = {
			
			if isFolderDrop {
				return dataSource.itemIdentifier(for: destIndexPath)
			} else {
				if destIndexPath.row == 0 {
					return coordinator.rootNode.childAtIndex(destIndexPath.section)!
				} else if destIndexPath.row > 0 {
					return dataSource.itemIdentifier(for: IndexPath(row: destIndexPath.row - 1, section: destIndexPath.section))
				} else {
					return nil
				}
			}
				
		}()

		// Now we start looking for the parent container
		let destParentNode: Node? = {
			if destNode?.representedObject is Container {
				return destNode
			} else {
				if destNode?.parent?.representedObject is Container {
					return destNode!.parent!
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
		guard sourceContainer !== destinationContainer else { return }
		
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

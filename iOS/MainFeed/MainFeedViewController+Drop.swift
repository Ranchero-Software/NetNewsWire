//
//  MainFeedViewController+Drop.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Account
import RSTree

extension MainFeedViewController: UITableViewDropDelegate {

	func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
		return session.localDragSession != nil
	}

	func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
		guard let destIndexPath = destinationIndexPath, destIndexPath.section > 0, tableView.hasActiveDrag else {
			return UITableViewDropProposal(operation: .forbidden)
		}

		guard let destFeed = coordinator.nodeFor(destIndexPath)?.representedObject as? SidebarItem,
			  let destAccount = destFeed.account,
			  let destCell = tableView.cellForRow(at: destIndexPath) else {
				  return UITableViewDropProposal(operation: .forbidden)
			  }

		// Validate account specific behaviors...
		if destAccount.behaviors.contains(.disallowFeedInMultipleFolders),
		   let sourceNode = session.localDragSession?.items.first?.localObject as? Node,
		   let sourceFeed = sourceNode.representedObject as? Feed,
		   sourceFeed.account?.accountID != destAccount.accountID && destAccount.hasFeed(withURL: sourceFeed.url) {
			return UITableViewDropProposal(operation: .forbidden)
		}

		// Determine the correct drop proposal
		if destFeed is Folder {
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
			  let dragNode = dragItem.localObject as? Node,
			  let source = dragNode.parent?.representedObject as? Container,
			  let destIndexPath = dropCoordinator.destinationIndexPath else {
				  return
			  }

		let isFolderDrop: Bool = {
			if coordinator.nodeFor(destIndexPath)?.representedObject is Folder, let propCell = tableView.cellForRow(at: destIndexPath) {
				return dropCoordinator.session.location(in: propCell).y >= 0
			}
			return false
		}()

		// Based on the drop we have to determine a node to start looking for a parent container.
		let destNode: Node? = {

			if isFolderDrop {
				return coordinator.nodeFor(destIndexPath)
			} else {
				if destIndexPath.row == 0 {
					return coordinator.nodeFor(IndexPath(row: 0, section: destIndexPath.section))
				} else if destIndexPath.row > 0 {
					return coordinator.nodeFor(IndexPath(row: destIndexPath.row - 1, section: destIndexPath.section))
				} else {
					return nil
				}
			}

		}()

		// Now we start looking for the parent container
		let destinationContainer: Container? = {
			if let container = (destNode?.representedObject as? Container) ?? (destNode?.parent?.representedObject as? Container) {
				return container
			} else {
				// If we got here, we are trying to drop on an empty section header.  Go and find the Account for this section
				return coordinator.rootNode.childAtIndex(destIndexPath.section)?.representedObject as? Account
			}
		}()

		guard let destination = destinationContainer, let feed = dragNode.representedObject as? Feed else { return }

		if source.account == destination.account {
			moveFeedInAccount(feed: feed, sourceContainer: source, destinationContainer: destination)
		} else {
			moveFeedBetweenAccounts(feed: feed, sourceContainer: source, destinationContainer: destination)
		}
	}

	func moveFeedInAccount(feed: Feed, sourceContainer: Container, destinationContainer: Container) {
		guard sourceContainer !== destinationContainer else { return }

		BatchUpdate.shared.start()
		sourceContainer.account?.moveFeed(feed, from: sourceContainer, to: destinationContainer) { result in
			BatchUpdate.shared.end()
			switch result {
			case .success:
				break
			case .failure(let error):
				self.presentError(error)
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
			destinationContainer.account?.createFeed(url: feed.url, name: feed.editedName, container: destinationContainer, validateFeed: false) { result in
				switch result {
				case .success:
					sourceContainer.account?.removeFeed(feed, from: sourceContainer) { result in
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

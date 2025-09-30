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
	
	func tableView(
		_ tableView: UITableView,
		dropSessionDidUpdate session: UIDropSession,
		withDestinationIndexPath destinationIndexPath: IndexPath?
	) -> UITableViewDropProposal {
		Self.logger.debug("--- dropSessionDidUpdate: destinationIndexPath = \(destinationIndexPath?.debugDescription ?? "nil")")
		Self.logger.debug("dropSessionDidUpdate: tableView.hasActiveDrag = \(tableView.hasActiveDrag)")

		guard let destIndexPath = destinationIndexPath,
			  destIndexPath.section > 0,
			  tableView.hasActiveDrag else {
			Self.logger.debug("dropSessionDidUpdate: returning .forbidden after guard let destIndexPath = destinationIndexPath, destIndexPath.section > 0, tableView.hasActiveDrag")
			return UITableViewDropProposal(operation: .forbidden)
		}

		// Get the destination account - either from a feed or directly from the section if empty
		let destinationAccount: Account? = {
			if let destFeed = coordinator.nodeFor(destIndexPath)?.representedObject as? Feed {
				return destFeed.account
			} else {
				// Empty section - get account directly
				return coordinator.rootNode.childAtIndex(destIndexPath.section)?.representedObject as? Account
			}
		}()
		
		guard let destinationAccount else {
			Self.logger.debug("dropSessionDidUpdate: returning .forbidden - could not determine destination account")
			return UITableViewDropProposal(operation: .forbidden)
		}

		// Validate account specific behaviors...
		if destinationAccount.behaviors.contains(.disallowFeedInMultipleFolders),
		   let sourceNode = session.localDragSession?.items.first?.localObject as? Node,
		   let sourceWebFeed = sourceNode.representedObject as? WebFeed,
		   sourceWebFeed.account?.accountID != destinationAccount.accountID && destinationAccount.hasWebFeed(withURL: sourceWebFeed.url) {
			Self.logger.debug("dropSessionDidUpdate: returning .forbidden after guard statement validating account behaviors")
			return UITableViewDropProposal(operation: .forbidden)
		}

		// Determine the correct drop proposal
		let destFeed = coordinator.nodeFor(destIndexPath)?.representedObject as? Feed
		let destCell = tableView.cellForRow(at: destIndexPath)
		
		if let destFeed, destFeed is Folder, let destCell {
			if session.location(in: destCell).y >= 0 {
				Self.logger.debug("dropSessionDidUpdate: returning .move with intent .insertIntoDestinationIndexPath")
				return UITableViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
			} else {
				Self.logger.debug("dropSessionDidUpdate: returning .move with intent .unspecified)")
				return UITableViewDropProposal(operation: .move, intent: .unspecified)
			}
		} else {
			// Either dropping on a feed or into an empty section
			Self.logger.debug("dropSessionDidUpdate: returning .move with intent .insertAtDestinationIndexPath")
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
		
		guard let destination = destinationContainer, let webFeed = dragNode.representedObject as? WebFeed else { return }
		
		if source.account == destination.account {
			moveWebFeedInAccount(feed: webFeed, sourceContainer: source, destinationContainer: destination)
		} else {
			moveWebFeedBetweenAccounts(feed: webFeed, sourceContainer: source, destinationContainer: destination)
		}
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
			destinationContainer.account?.createWebFeed(url: feed.url, name: feed.editedName, container: destinationContainer, validateFeed: false) { result in
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

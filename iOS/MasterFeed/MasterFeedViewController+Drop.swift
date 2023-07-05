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
		guard tableView.hasActiveDrag else {
			return UITableViewDropProposal(operation: .forbidden)
		}
		
		guard let sourceNode = session.localDragSession?.items.first?.localObject as? Node,
			  let sourceWebFeed = sourceNode.representedObject as? Feed else {
			return UITableViewDropProposal(operation: .forbidden)
		}

		var successOperation = UIDropOperation.move
		
		if let destinationIndexPath = destinationIndexPath,
		   let sourceIndexPath = coordinator.indexPathFor(sourceNode),
		   destinationIndexPath.section != sourceIndexPath.section {
			successOperation = .copy
		}
		
		guard let correctedIndexPath = correctDestinationIndexPath(session: session) else {
			// We didn't hit the corrected indexPath, but this at least it gets the section right
			guard let section = destinationIndexPath?.section,
				  let account = coordinator.nodeFor(section)?.representedObject as? Account,
				  !account.hasChildWebFeed(withURL: sourceWebFeed.url) else {
				return UITableViewDropProposal(operation: .forbidden)
			}
			
			return UITableViewDropProposal(operation: successOperation, intent: .insertAtDestinationIndexPath)
		}
		
		guard correctedIndexPath.section > 0 else {
			return UITableViewDropProposal(operation: .forbidden)
		}
		
		guard let correctDestNode = coordinator.nodeFor(correctedIndexPath),
			  let correctDestFeed = correctDestNode.representedObject as? FeedProtocol,
			  let correctDestAccount = correctDestFeed.account else {
			return UITableViewDropProposal(operation: .forbidden)
		}
		
		// Validate account specific behaviors...
		if correctDestAccount.behaviors.contains(.disallowFeedInMultipleFolders),
		   sourceWebFeed.account?.accountID != correctDestAccount.accountID && correctDestAccount.hasFeed(withURL: sourceWebFeed.url) {
			return UITableViewDropProposal(operation: .forbidden)
		}

		// Determine the correct drop proposal
		if let correctFolder = correctDestFeed as? Folder {
			if correctFolder.hasChildWebFeed(withURL: sourceWebFeed.url) {
				return UITableViewDropProposal(operation: .forbidden)
			} else {
				return UITableViewDropProposal(operation: successOperation, intent: .insertIntoDestinationIndexPath)
			}
		} else {
			if let parentContainer = correctDestNode.parent?.representedObject as? Container, !parentContainer.hasChildWebFeed(withURL: sourceWebFeed.url) {
				return UITableViewDropProposal(operation: successOperation, intent: .insertAtDestinationIndexPath)
			} else {
				return UITableViewDropProposal(operation: .forbidden)
			}
		}

	}
	
	func tableView(_ tableView: UITableView, performDropWith dropCoordinator: UITableViewDropCoordinator) {
		guard let dragItem = dropCoordinator.items.first?.dragItem,
			  let dragNode = dragItem.localObject as? Node,
			  let source = dragNode.parent?.representedObject as? Container else {
			return
		}
		
		// Based on the drop we have to determine a node to start looking for a parent container.
		let destNode: Node? = {
			guard let destIndexPath = correctDestinationIndexPath(session: dropCoordinator.session) else { return nil }
			
			if coordinator.nodeFor(destIndexPath)?.representedObject is Folder {
				if dropCoordinator.proposal.intent == .insertAtDestinationIndexPath {
					return coordinator.nodeFor(destIndexPath.section)
				} else {
					return coordinator.nodeFor(destIndexPath)
				}
			} else {
				return nil
			}
		}()

		// Now we start looking for the parent container
		let destinationContainer: Container? = {
			if let container = (destNode?.representedObject as? Container) ?? (destNode?.parent?.representedObject as? Container) {
				return container
			} else {
				// We didn't hit the corrected indexPath, but this at least gets the section right
				guard let section = dropCoordinator.destinationIndexPath?.section else { return nil }
				
				// If we got here, we are trying to drop on an empty section header.  Go and find the Account for this section
				return coordinator.nodeFor(section)?.representedObject as? Account
			}
		}()
		
		guard let destination = destinationContainer, let webFeed = dragNode.representedObject as? Feed else { return }
		
		if source.account == destination.account {
			moveFeedInAccount(feed: webFeed, sourceContainer: source, destinationContainer: destination)
		} else {
			copyWebFeedBetweenAccounts(feed: webFeed, sourceContainer: source, destinationContainer: destination)
		}
	}
	
}

private extension MasterFeedViewController {

	func correctDestinationIndexPath(session: UIDropSession) -> IndexPath? {
		let location = session.location(in: tableView)
		
		var correctDestination: IndexPath?
		tableView.performUsingPresentationValues {
			correctDestination = tableView.indexPathForRow(at: location)
		}
		
		return correctDestination
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
	
	func copyWebFeedBetweenAccounts(feed: Feed, sourceContainer: Container, destinationContainer: Container) {
		
		if let existingFeed = destinationContainer.account?.existingFeed(withURL: feed.url) {
			
			BatchUpdate.shared.start()
			destinationContainer.account?.addFeed(existingFeed, to: destinationContainer) { result in
				switch result {
				case .success:
					BatchUpdate.shared.end()
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
					BatchUpdate.shared.end()
				case .failure(let error):
					BatchUpdate.shared.end()
					self.presentError(error)
				}
			}
			
		}
	}


}

private extension Container {
	
	func hasChildWebFeed(withURL url: String) -> Bool {
		return topLevelFeeds.contains(where: { $0.url == url })
	}
	
}

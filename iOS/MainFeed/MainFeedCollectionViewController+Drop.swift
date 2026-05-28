//
//  MainFeedCollectionViewController+Drop.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 14/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit
import WebKit
import Account
import Articles
import RSCore
import RSTree
import RSWeb
import SafariServices
import UniformTypeIdentifiers

extension MainFeedCollectionViewController: UICollectionViewDropDelegate {

	func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: any UICollectionViewDropCoordinator) {
		guard let dropItem = coordinator.items.first,
			  let dragNode = dropItem.dragItem.localObject as? Node,
			  let source = dragNode.parent?.representedObject as? Container,
			  let destIndexPath = coordinator.destinationIndexPath else {
				  return
			  }

		let isFolderDrop: Bool = {
			if dataSource.itemIdentifier(for: destIndexPath)?.node.representedObject is Folder, let propCell = collectionView.cellForItem(at: destIndexPath) {
				return coordinator.session.location(in: propCell).y >= 0
			}
			return false
		}()

		// Based on the drop we have to determine a node to start looking for a parent container.
		let destNode: Node? = {

			if isFolderDrop {
				return dataSource.itemIdentifier(for: destIndexPath)?.node
			} else {
				if destIndexPath.row == 0 {
					return dataSource.itemIdentifier(for: IndexPath(row: 0, section: destIndexPath.section))?.node
				} else if destIndexPath.row > 0 {
					return dataSource.itemIdentifier(for: IndexPath(row: destIndexPath.row - 1, section: destIndexPath.section))?.node
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
				let sectionID = dataSource.snapshot().sectionIdentifiers[destIndexPath.section]
				return AccountManager.shared.existingAccount(accountID: sectionID)
			}
		}()

		guard let destination = destinationContainer, let feed = dragNode.representedObject as? Feed else { return }

		if source.account == destination.account {
			if source === destination, !isFolderDrop, destination.topLevelFeeds.contains(feed) {
				reorderFeedInAccount(feed: feed, in: destination, sourceIndexPath: dropItem.sourceIndexPath, destinationIndexPath: destIndexPath)
			} else {
				moveFeedInAccount(feed: feed, sourceContainer: source, destinationContainer: destination)
			}
		} else {
			moveFeedBetweenAccounts(feed: feed, sourceContainer: source, destinationContainer: destination)
		}
	}

	func reorderFeedInAccount(feed: Feed, in container: Container, sourceIndexPath: IndexPath?, destinationIndexPath: IndexPath) {
		guard let account = container.account else { return }

		// `destinationIndexPath` is in the post-removal coordinate space (the dragged item is
		// treated as already removed). When the dragged feed sits at or above that row in the
		// current snapshot, the node to insert *before* is one row further down.
		let beforeRow: Int
		if let sourceRow = sourceIndexPath?.row, sourceRow <= destinationIndexPath.row {
			beforeRow = destinationIndexPath.row + 1
		} else {
			beforeRow = destinationIndexPath.row
		}
		let beforeFeed = dataSource.itemIdentifier(for: IndexPath(row: beforeRow, section: destinationIndexPath.section))?.node.representedObject as? Feed

		let currentOrder = container.topLevelFeedsInDisplayOrder()
		let newOrder = currentOrder.reordered(moving: feed, before: beforeFeed)
		guard newOrder != currentOrder else { return }
		Task { @MainActor in
			do {
				try await account.reorderFeeds(newOrder, in: container)
			} catch {
				self.presentError(error)
			}
		}
	}

	func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: any UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {

		guard let destIndexPath = destinationIndexPath, destIndexPath.section > 0, collectionView.hasActiveDrag else {
			return UICollectionViewDropProposal(operation: .forbidden)
		}

		guard let destFeed = dataSource.itemIdentifier(for: destIndexPath)?.node.representedObject as? SidebarItem,
			  let destAccount = destFeed.account,
			  let destCell = collectionView.cellForItem(at: destIndexPath) else {
				  return UICollectionViewDropProposal(operation: .forbidden)
			  }

		// Validate account specific behaviors...
		if destAccount.behaviors.contains(.disallowFeedInMultipleFolders),
		   let sourceNode = session.localDragSession?.items.first?.localObject as? Node,
		   let sourceFeed = sourceNode.representedObject as? Feed,
		   sourceFeed.account?.accountID != destAccount.accountID && destAccount.hasFeed(withURL: sourceFeed.url) {
			return UICollectionViewDropProposal(operation: .forbidden)
		}

		// Determine the correct drop proposal
		if destFeed is Folder {
			if session.location(in: destCell).y >= 0 {
				return UICollectionViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
			} else {
				return UICollectionViewDropProposal(operation: .move, intent: .unspecified)
			}
		} else {
			return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
		}
	}

	func collectionView(_ collectionView: UICollectionView, canHandle session: any UIDropSession) -> Bool {
		return session.localDragSession != nil
	}

	func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
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

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
			let destIdentifier = dataSource.itemIdentifier(for: destIndexPath),
			let destCell = tableView.cellForRow(at: destIndexPath) else {
				return UITableViewDropProposal(operation: .forbidden)
		}
		
		if destIdentifier.isFolder {
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
			let sourceIdentifier = dragItem.localObject as? MasterFeedTableViewIdentifier,
			let sourceParentContainerID = sourceIdentifier.parentContainerID,
			let source = AccountManager.shared.existingContainer(with: sourceParentContainerID),
			let destIndexPath = dropCoordinator.destinationIndexPath else {
				return
		}
		
		let isFolderDrop: Bool = {
			if let propDestIdentifier = dataSource.itemIdentifier(for: destIndexPath), let propCell = tableView.cellForRow(at: destIndexPath) {
				return propDestIdentifier.isFolder && dropCoordinator.session.location(in: propCell).y >= 0
			}
			return false
		}()
		
		// Based on the drop we have to determine a node to start looking for a parent container.
		let destIdentifier: MasterFeedTableViewIdentifier? = {
			
			if isFolderDrop {
				return dataSource.itemIdentifier(for: destIndexPath)
			} else {
				if destIndexPath.row == 0 {
					return dataSource.itemIdentifier(for: IndexPath(row: 0, section: destIndexPath.section))
				} else if destIndexPath.row > 0 {
					return dataSource.itemIdentifier(for: IndexPath(row: destIndexPath.row - 1, section: destIndexPath.section))
				} else {
					return nil
				}
			}
				
		}()

		// Now we start looking for the parent container
		let destinationContainer: Container? = {
			if let containerID = destIdentifier?.containerID ?? destIdentifier?.parentContainerID {
				return AccountManager.shared.existingContainer(with: containerID)
			} else {
				return nil
			}
		}()
		
		guard let destination = destinationContainer else { return }
		guard case .webFeed(_, let webFeedID) = sourceIdentifier.feedID else { return }
		guard let webFeed = source.existingWebFeed(withWebFeedID: webFeedID) else { return }
		
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

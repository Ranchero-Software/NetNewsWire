//
//  UpdateSelectionOperation.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/22/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

class UpdateSelectionOperation: MainThreadOperation {
	
	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "UpdateSelectionOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private var coordinator: SceneCoordinator
	private var dataSource: MasterFeedDataSource
	private var tableView: UITableView
	private var animations: Animations
	
	init(coordinator: SceneCoordinator, dataSource: MasterFeedDataSource, tableView: UITableView, animations: Animations) {
		self.coordinator = coordinator
		self.dataSource = dataSource
		self.tableView = tableView
		self.animations = animations
	}
	
	func run() {
		if dataSource.snapshot().numberOfItems > 0 {
			if let indexPath = coordinator.currentFeedIndexPath {
				CATransaction.begin()
				CATransaction.setCompletionBlock {
					self.operationDelegate?.operationDidComplete(self)
				}
				tableView.selectRowAndScrollIfNotVisible(at: indexPath, animations: animations)
				CATransaction.commit()
			} else {
				if animations.contains(.select) {
					CATransaction.begin()
					CATransaction.setCompletionBlock {
						self.operationDelegate?.operationDidComplete(self)
					}
					tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
					CATransaction.commit()
				} else {
					tableView.selectRow(at: nil, animated: false, scrollPosition: .none)
					self.operationDelegate?.operationDidComplete(self)
				}
			}
		} else {
			self.operationDelegate?.operationDidComplete(self)
		}
	}
	
}

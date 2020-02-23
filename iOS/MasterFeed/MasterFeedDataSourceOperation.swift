//
//  MasterFeedDataSourceOperation.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/23/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import RSTree

class MasterFeedDataSourceOperation: MainThreadOperation {
	
	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "MasterFeedDataSourceOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private var dataSource: UITableViewDiffableDataSource<Node, Node>
	private var snapshot: NSDiffableDataSourceSnapshot<Node, Node>
	private var animating: Bool
	
	init(dataSource: UITableViewDiffableDataSource<Node, Node>, snapshot: NSDiffableDataSourceSnapshot<Node, Node>, animating: Bool) {
		self.dataSource = dataSource
		self.snapshot = snapshot
		self.animating = animating
	}
	
	func run() {
		dataSource.apply(snapshot, animatingDifferences: animating) { [weak self] in
			guard let self = self else { return }
			self.operationDelegate?.operationDidComplete(self)
		}
	}
	
}

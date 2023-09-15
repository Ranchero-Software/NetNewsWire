//
//  FeedlySendArticleStatusesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 14/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import SyncDatabase
import RSCore


/// Take changes to statuses of articles locally and apply them to the corresponding the articles remotely.
final class FeedlySendArticleStatusesOperation: FeedlyOperation, Logging {

	private let database: SyncDatabase
	private let service: FeedlyMarkArticlesService

	init(database: SyncDatabase, service: FeedlyMarkArticlesService) {
		self.database = database
		self.service = service
	}
	
	override func run() {
		Task { @MainActor in
			logger.debug("Sending article statuses...")

			do {
				let syncStatuses = try await database.selectForProcessing()
				self.processStatuses(Array(syncStatuses))
			} catch {
				self.didFinish()
			}
		}
	}
}

private extension FeedlySendArticleStatusesOperation {

	func processStatuses(_ pending: [SyncStatus]) {
		let statuses: [(status: SyncStatus.Key, flag: Bool, action: FeedlyMarkAction)] = [
			(.read, false, .unread),
			(.read, true, .read),
			(.starred, true, .saved),
			(.starred, false, .unsaved),
		]

		let group = DispatchGroup()

		for pairing in statuses {
			let articleIDs = pending.filter { $0.key == pairing.status && $0.flag == pairing.flag }
			guard !articleIDs.isEmpty else {
				continue
			}

			let ids = Set(articleIDs.map { $0.articleID })
			let database = self.database
			group.enter()
			service.mark(ids, as: pairing.action) { result in
				Task { @MainActor in
					switch result {
					case .success:
						try? await database.deleteSelectedForProcessing(Array(ids))
					case .failure:
						try? await database.resetSelectedForProcessing(Array(ids))
					}
					group.leave()
				}
			}
		}

		group.notify(queue: DispatchQueue.main) {
            self.logger.debug("Done sending article statuses.")
			self.didFinish()
		}
	}
}

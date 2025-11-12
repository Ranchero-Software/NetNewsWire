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
import os.log


/// Take changes to statuses of articles locally and apply them to the corresponding the articles remotely.
final class FeedlySendArticleStatusesOperation: FeedlyOperation, @unchecked Sendable {
	private let database: SyncDatabase
	private let service: FeedlyMarkArticlesService

	@MainActor init(database: SyncDatabase, service: FeedlyMarkArticlesService) {
		self.database = database
		self.service = service
		super.init()
	}

	override func run() {
		Task { @MainActor in
			Feedly.logger.info("Feedly: Sending article statuses")

			do {
				guard let syncStatuses = try await database.selectForProcessing() else {
					didComplete()
					return
				}
				processStatuses(Array(syncStatuses))
			} catch {
				didComplete()
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
			let articleIds = pending.filter { $0.key == pairing.status && $0.flag == pairing.flag }
			guard !articleIds.isEmpty else {
				continue
			}

			let ids = Set(articleIds.map { $0.articleID })
			let database = self.database
			group.enter()
			service.mark(ids, as: pairing.action) { result in
				Task { @MainActor in
					switch result {
					case .success:
						try? await database.deleteSelectedForProcessing(ids)
						group.leave()
					case .failure:
						try? await database.resetSelectedForProcessing(ids)
						group.leave()
					}
				}
			}
		}

		Task { @MainActor in
			Feedly.logger.info("Feedly: Finished sending article statuses")
			self.didComplete()
		}
	}
}

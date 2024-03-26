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
final class FeedlySendArticleStatusesOperation: FeedlyOperation {

	private let database: SyncDatabase
	private let log: OSLog
	private let service: FeedlyMarkArticlesService

	init(database: SyncDatabase, service: FeedlyMarkArticlesService, log: OSLog) {
		self.database = database
		self.service = service
		self.log = log
	}
	
	override func run() {
		os_log(.debug, log: log, "Sending article statuses...")

		Task { @MainActor in

			do {
				let syncStatuses = (try await self.database.selectForProcessing()) ?? Set<SyncStatus>()
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
						try? await database.deleteSelectedForProcessing(Array(ids))
						group.leave()
					case .failure:
						try? await database.resetSelectedForProcessing(Array(ids))
						group.leave()
					}
				}
			}
		}

		group.notify(queue: DispatchQueue.main) {
			os_log(.debug, log: self.log, "Done sending article statuses.")
			self.didFinish()
		}
	}
}

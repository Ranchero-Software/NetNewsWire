//
//  CloudKitReceiveStatusOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore
import CloudKitSync

final class CloudKitReceiveStatusOperation: MainThreadOperation, @unchecked Sendable {
	private weak var articlesZone: CloudKitArticlesZone?
	private static let logger = cloudKitLogger

	init(articlesZone: CloudKitArticlesZone) {
		self.articlesZone = articlesZone
		super.init(name: "CloudKitReceiveStatusOperation")
	}

	@MainActor override func run() {
		guard let articlesZone else {
			self.didComplete()
			return
		}

		Task { @MainActor in
			defer {
				self.didComplete()
			}

			Self.logger.debug("iCloud: Refreshing article statuses")
			do {
				try await articlesZone.refreshArticles()
				Self.logger.debug("iCloud: Finished refreshing article statuses")
			} catch {
				Self.logger.error("iCloud: Receive status error: \(error.localizedDescription)")
			}
		}
	}
}

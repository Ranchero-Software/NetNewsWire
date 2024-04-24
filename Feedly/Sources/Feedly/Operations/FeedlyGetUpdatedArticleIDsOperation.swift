//
//  FeedlyGetUpdatedArticleIDsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 11/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Secrets

/// Single responsibility is to identify articles that have changed since a particular date.
///
/// Typically, it pages through the article ids of the global.all stream.
/// When all the article ids are collected, it is the responsibility of another operation to download them when appropriate.
public final class FeedlyGetUpdatedArticleIDsOperation: FeedlyOperation, FeedlyEntryIdentifierProviding {

	private let resource: FeedlyResourceID
	private let service: FeedlyGetStreamIDsService
	private let newerThan: Date?
	private let log: OSLog
	
	public init(resource: FeedlyResourceID, service: FeedlyGetStreamIDsService, newerThan: Date?, log: OSLog) {

		self.resource = resource
		self.service = service
		self.newerThan = newerThan
		self.log = log
	}
	
	public convenience init(userID: String, service: FeedlyGetStreamIDsService, newerThan: Date?, log: OSLog) {
		let all = FeedlyCategoryResourceID.Global.all(for: userID)
		self.init(resource: all, service: service, newerThan: newerThan, log: log)
	}
	
	public var entryIDs: Set<String> {
		return storedUpdatedArticleIDs
	}
	
	private var storedUpdatedArticleIDs = Set<String>()
	
	public override func run() {
		getStreamIDs(nil)
	}
	
	private func getStreamIDs(_ continuation: String?) {

		Task { @MainActor in
			guard let date = newerThan else {
				os_log(.debug, log: log, "No date provided so everything must be new (nothing is updated).")
				didFinish()
				return
			}

			do {
				let streamIDs = try await service.getStreamIDs(for: resource, continuation: continuation, newerThan: date, unreadOnly: nil)

				storedUpdatedArticleIDs.formUnion(streamIDs.ids)
				guard let continuation = streamIDs.continuation else {
					os_log(.debug, log: log, "%{public}i articles updated since last successful sync start date.", storedUpdatedArticleIDs.count)
					didFinish()
					return
				}

				getStreamIDs(continuation)

			} catch {
				didFinish(with: error)
			}
		}
	}
}

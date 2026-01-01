//
//  ExtensionFeedAddRequestFile.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Synchronization
import os.log
import Account

final class ExtensionFeedAddRequestFile: NSObject, NSFilePresenter, Sendable {
	static let shared = ExtensionFeedAddRequestFile()

	static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ExtensionFeedAddRequestFile")

	private static let filePath: String = {
		let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
		let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
		return containerURL!.appendingPathComponent("extension_feed_add_request.plist").path
	}()

	private let operationQueue = {
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		return queue
	}()

	var presentedItemURL: URL? {
		URL(fileURLWithPath: ExtensionFeedAddRequestFile.filePath)
	}

	var presentedItemOperationQueue: OperationQueue {
		operationQueue
	}

	private let didStart = Mutex(false)

	func start() {
		var shouldBail = false
		didStart.withLock { didStart in
			if didStart {
				shouldBail = true
				assertionFailure("start called when already did start")
				return
			}

			didStart = true
		}

		if shouldBail {
			return
		}

		NSFileCoordinator.addFilePresenter(self)
		Task { @MainActor in
			process()
		}
	}

	func presentedItemDidChange() {
		Task { @MainActor in
			process()
		}
	}

	func resume() {
		didStart.withLock { didStart in
			assert(didStart)
		}

		NSFileCoordinator.addFilePresenter(self)
		Task { @MainActor in
			process()
		}
	}

	func suspend() {
		didStart.withLock { didStart in
			assert(didStart)
		}
		NSFileCoordinator.removeFilePresenter(self)
	}

	static func save(_ feedAddRequest: ExtensionFeedAddRequest) {

		let decoder = PropertyListDecoder()
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator()
		let fileURL = URL(fileURLWithPath: ExtensionFeedAddRequestFile.filePath)

		fileCoordinator.coordinate(writingItemAt: fileURL, options: [.forMerging], error: errorPointer, byAccessor: { url in
			do {

				var requests: [ExtensionFeedAddRequest]
				if let fileData = try? Data(contentsOf: url),
					let decodedRequests = try? decoder.decode([ExtensionFeedAddRequest].self, from: fileData) {
					requests = decodedRequests
				} else {
					requests = [ExtensionFeedAddRequest]()
				}

				requests.append(feedAddRequest)

				let data = try encoder.encode(requests)
				try data.write(to: url)

			} catch let error as NSError {
				Self.logger.error("Save to disk failed: \(error.localizedDescription)")
			}
		})

		if let error = errorPointer?.pointee {
			Self.logger.error("Save to disk coordination failed: \(error.localizedDescription)")
		}
	}
}

@MainActor private extension ExtensionFeedAddRequestFile {

	func process() {

		let decoder = PropertyListDecoder()
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator(filePresenter: self)
		let fileURL = URL(fileURLWithPath: ExtensionFeedAddRequestFile.filePath)

		var requests: [ExtensionFeedAddRequest]?

		fileCoordinator.coordinate(writingItemAt: fileURL, options: [.forMerging], error: errorPointer, byAccessor: { url in
			do {

				if let fileData = try? Data(contentsOf: url),
					let decodedRequests = try? decoder.decode([ExtensionFeedAddRequest].self, from: fileData) {
					requests = decodedRequests
				}

				let data = try encoder.encode([ExtensionFeedAddRequest]())
				try data.write(to: url)

			} catch let error as NSError {
				Self.logger.error("Save to disk failed: \(error.localizedDescription)")
			}
		})

		if let error = errorPointer?.pointee {
			Self.logger.error("Save to disk coordination failed: \(error.localizedDescription)")
		}

		requests?.forEach { processRequest($0) }
	}

	func processRequest(_ request: ExtensionFeedAddRequest) {
		var destinationAccountID: String?
		switch request.destinationContainerID {
		case .account(let accountID):
			destinationAccountID = accountID
		case .folder(let accountID, _):
			destinationAccountID = accountID
		default:
			break
		}

		guard let accountID = destinationAccountID, let account = AccountManager.shared.existingAccount(accountID: accountID) else {
			return
		}

		var destinationContainer: Container?
		if account.containerID == request.destinationContainerID {
			destinationContainer = account
		} else {
			destinationContainer = account.folders?.first(where: { $0.containerID == request.destinationContainerID })
		}

		guard let container = destinationContainer else { return }

		account.createFeed(url: request.feedURL.absoluteString, name: request.name, container: container, validateFeed: true) { _ in }
	}
}

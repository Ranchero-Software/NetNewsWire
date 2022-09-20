//
//  ExtensionFeedAddRequestFile.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import RSCore

final class ExtensionFeedAddRequestFile: NSObject, NSFilePresenter, Logging {
	
	private static var filePath: String = {
		let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
		let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
		return containerURL!.appendingPathComponent("extension_feed_add_request.plist").path
	}()
	
	private let operationQueue: OperationQueue
	
	var presentedItemURL: URL? {
		return URL(fileURLWithPath: ExtensionFeedAddRequestFile.filePath)
	}
	
	var presentedItemOperationQueue: OperationQueue {
		return operationQueue
	}
	
	override init() {
		operationQueue = OperationQueue()
		operationQueue.maxConcurrentOperationCount = 1
		
		super.init()
		
		NSFileCoordinator.addFilePresenter(self)
		process()
	}

	func presentedItemDidChange() {
		DispatchQueue.main.async {
			self.process()
		}
	}

	func resume() {
		NSFileCoordinator.addFilePresenter(self)
		process()
	}
	
	func suspend() {
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
				logger.error("Save to disk failed: \(error.localizedDescription, privacy: .public)")
			}
		})
		
		if let error = errorPointer?.pointee {
			logger.error("Save to disk coordination failed: \(error.localizedDescription, privacy: .public)")
		}
	}
	
}

private extension ExtensionFeedAddRequestFile {
	
	func process() {
		
		let decoder = PropertyListDecoder()
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator(filePresenter: self)
		let fileURL = URL(fileURLWithPath: ExtensionFeedAddRequestFile.filePath)

		var requests: [ExtensionFeedAddRequest]? = nil

		fileCoordinator.coordinate(writingItemAt: fileURL, options: [.forMerging], error: errorPointer, byAccessor: { [weak self] url in
			do {
				
				if let fileData = try? Data(contentsOf: url),
					let decodedRequests = try? decoder.decode([ExtensionFeedAddRequest].self, from: fileData) {
					requests = decodedRequests
				}
				
				let data = try encoder.encode([ExtensionFeedAddRequest]())
				try data.write(to: url)
				
			} catch let error as NSError {
				self?.logger.error("Save to disk failed: \(error.localizedDescription, privacy: .public)")
			}
		})
		
		if let error = errorPointer?.pointee {
			logger.error("Save to disk coordination failed: \(error.localizedDescription, privacy: .public)")
		}

		requests?.forEach { processRequest($0) }
	}
	
	func processRequest(_ request: ExtensionFeedAddRequest) {
		var destinationAccountID: String? = nil
		switch request.destinationContainerID {
		case .account(let accountID):
			destinationAccountID = accountID
		case .folder(let accountID, _):
			destinationAccountID = accountID
		default:
			break
		}
		
		guard let accountID = destinationAccountID, let account = AccountManager.shared.existingAccount(with: accountID) else {
			return
		}
		
		var destinationContainer: Container? = nil
		if account.containerID == request.destinationContainerID {
			destinationContainer = account
		} else {
			destinationContainer = account.folders?.first(where: { $0.containerID == request.destinationContainerID })
		}
		
		guard let container = destinationContainer else { return }
		
		account.createWebFeed(url: request.feedURL.absoluteString, name: request.name, container: container, validateFeed: true) { _ in }
	}
	
}

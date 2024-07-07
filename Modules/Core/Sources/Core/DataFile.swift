//
//  DataFile.swift
//
//
//  Created by Brent Simmons on 6/9/24.
//

import Foundation
import os

public protocol DataFileDelegate: AnyObject {

	@MainActor func data(for dataFile: DataFile) -> Data?
	@MainActor func dataFileWriteToDiskDidFail(for dataFile: DataFile, error: Error)
}

@MainActor public final class DataFile {

	public weak var delegate: DataFileDelegate? = nil

	private var isDirty = false {
		didSet {
			if isDirty {
				saveQueue.add(self, #selector(saveToDiskIfNeeded))
			}
		}
	}

	private let fileURL: URL
	private let saveQueue: CoalescingQueue
	
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DataFile")
	private var logger: Logger {
		Self.logger
	}

	public init(fileURL: URL) {

		self.fileURL = fileURL
		self.saveQueue = CoalescingQueue(name: "DataFile \(fileURL.absoluteString)", interval: 1.0)
	}

	public func markAsDirty() {

		isDirty = true
		logger.info("Data file marked dirty: \(self.fileURL)")
	}

	public func save() {

		assert(Thread.isMainThread)
		isDirty = false
		logger.info("Saving data file: \(self.fileURL)")

		guard let data = delegate?.data(for: self) else {
			logger.error("Delegate did not return data for data file: \(self.fileURL)")
			return
		}

		do {
			try data.write(to: fileURL)
		} catch {
			delegate?.dataFileWriteToDiskDidFail(for: self, error: error)
			logger.error("Data file did fail to write to disk: \(self.fileURL)")
		}
	}
}

private extension DataFile {

	@objc func saveToDiskIfNeeded() {

		if isDirty {
			save()
		}
	}
}

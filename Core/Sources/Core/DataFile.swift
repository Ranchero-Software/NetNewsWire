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

	public init(fileURL: URL) {

		self.fileURL = fileURL
		self.saveQueue = CoalescingQueue(name: "DataFile \(fileURL.absoluteString)", interval: 1.0, maxInterval: 2.0)
	}

	public func markAsDirty() {

		isDirty = true
	}

	public func save() {

		assert(Thread.isMainThread)
		isDirty = false

		guard let data = delegate?.data(for: self) else {
			return
		}

		do {
			try data.write(to: fileURL)
		} catch {
			delegate?.dataFileWriteToDiskDidFail(for: self, error: error)
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

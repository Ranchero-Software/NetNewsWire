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
				restartTimer()
			}
			else {
				invalidateTimer()
			}
		}
	}

	private let fileURL: URL
	private let saveInterval: TimeInterval = 1.0
	private var timer: Timer?

	public init(fileURL: URL) {
		
		self.fileURL = fileURL
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

	func saveToDiskIfNeeded() {

		assert(Thread.isMainThread)

		if isDirty {
			save()
		}
	}

	func restartTimer() {

		assert(Thread.isMainThread)

		invalidateTimer()

		timer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: false) { timer in
			MainActor.assumeIsolated {
				self.saveToDiskIfNeeded()
			}
		}
	}

	func invalidateTimer() {

		assert(Thread.isMainThread)

		if let timer, timer.isValid {
			timer.invalidate()
		}
		timer = nil
	}
}

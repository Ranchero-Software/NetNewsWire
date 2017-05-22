//
//  DiskSaver.swift
//  RSCore
//
//  Created by Brent Simmons on 12/28/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public final class DiskSaver: NSObject {
	
	private let path: String
	public weak var delegate: PlistProvider?
	private var coalescedSaveTimer: Timer?
	
	public var dirty = false {
		didSet {
			if dirty {
				coalescedSaveToDisk()
			}
			else {
				invalidateSaveTimer()
			}
		}
	}
	
	public init(path: String) {
		
		self.path = path
	}
	
	deinit {
		
		if let timer = coalescedSaveTimer, timer.isValid {
			timer.invalidate()
		}
	}
	
	private func invalidateSaveTimer() {
		
		if let timer = coalescedSaveTimer, timer.isValid {
			timer.invalidate()
		}
		coalescedSaveTimer = nil
	}

	private let coalescedSaveInterval = 1.0

	private func coalescedSaveToDisk() {
		
		invalidateSaveTimer()
		coalescedSaveTimer = Timer.scheduledTimer(timeInterval: coalescedSaveInterval, target: self, selector: #selector(saveToDisk), userInfo: nil, repeats: false)
	}
	
	public dynamic func saveToDisk() {
		
		invalidateSaveTimer()
		if !dirty {
			return
		}
		if let d = delegate?.plist {

			do {
				try RSPlist.write(d, filePath: path)
				dirty = false
			}
			catch {
				print("DiskSaver: error writing \(path) to disk.")
			}
		}
	}
}

//
//  DownloadProgress.swift
//  RSWeb
//
//  Created by Brent Simmons on 9/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension Notification.Name {
	
	public static let DownloadProgressDidChange = Notification.Name(rawValue: "DownloadProgressDidChangeNotification")
}

public class DownloadProgress {
	
	public var numberOfTasks = 0 {
		didSet {
			if numberOfTasks == 0 {
				numberRemaining = 0
			}
			postDidChangeNotification()
		}
	}
	
	public var numberRemaining = 0 {
		didSet {
			postDidChangeNotification()
		}
	}

	public var numberCompleted: Int {
		get {
			var n = numberOfTasks - numberRemaining
			if n < 0 {
				n = 0
			}
			if n > numberOfTasks {
				n = numberOfTasks
			}
			return n
		}
	}
	
	public var isComplete: Bool {
		get {
			return numberRemaining < 1
		}
	}
	
	public init(numberOfTasks: Int) {
		
		self.numberOfTasks = numberOfTasks
	}
	
	public func addToNumberOfTasks(_ n: Int) {
		
		numberOfTasks = numberOfTasks + n
	}
	
	public func clear() {
		
		numberOfTasks = 0
	}
}

private extension DownloadProgress {
	
	func postDidChangeNotification() {
		
		NotificationCenter.default.post(name: .DownloadProgressDidChange, object: self)
	}
}

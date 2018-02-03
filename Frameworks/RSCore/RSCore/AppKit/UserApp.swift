//
//  UserApp.swift
//  RSCore
//
//  Created by Brent Simmons on 1/14/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import AppKit

// Represents an app (the type of app mostly found in /Applications.)
// The app may or may not be running. It may or may not exist.

public final class UserApp {

	public let bundleID: String
	public var icon: NSImage? = nil
	public var existsOnDisk = false
	public var path: String? = nil
	public var runningApplication: NSRunningApplication? = nil

	public var isRunning: Bool {

		updateStatus()
		if let runningApplication = runningApplication {
			return !runningApplication.isTerminated
		}
		return false
	}

	public init(bundleID: String) {

		self.bundleID = bundleID
		updateStatus()
	}

	public func updateStatus() {

		if let runningApplication = runningApplication, runningApplication.isTerminated {
			self.runningApplication = nil
		}

		let runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
		for app in runningApplications {
			if let runningApplication = runningApplication {
				if app == runningApplication {
					break
				}
			}
			else {
				if !app.isTerminated {
					runningApplication = app
					break
				}
			}
		}

		if let runningApplication = runningApplication {
			existsOnDisk = true
			icon = runningApplication.icon
			if let bundleURL = runningApplication.bundleURL {
				path = bundleURL.path
			}
			else {
				path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleID)
			}
			if icon == nil, let path = path {
				icon = NSWorkspace.shared.icon(forFile: path)
			}
			return
		}

		path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleID)
		if let path = path {
			if icon == nil {
				icon = NSWorkspace.shared.icon(forFile: path)
			}
			existsOnDisk = true
		}
		else {
			existsOnDisk = false
			icon = nil
		}
	}

	public func launchIfNeeded() -> Bool {

		// Return true if already running.
		// Return true if not running and successfully gets launched.

		updateStatus()
		if isRunning {
			return true
		}

		guard existsOnDisk, let path = path else {
			return false
		}

		let url = URL(fileURLWithPath: path)
		if let app = try? NSWorkspace.shared.launchApplication(at: url, options: [.withErrorPresentation], configuration: [:]) {
			runningApplication = app
			if app.isFinishedLaunching {
				return true
			}
			Thread.sleep(forTimeInterval: 1.0) // Give the app time to launch. This is ugly.
			return true
		}

		return false
	}

	public func bringToFront() -> Bool {

		// Activates the app, ignoring other apps.
		// Does not automatically launch the app first.

		updateStatus()
		return runningApplication?.activate(options: [.activateIgnoringOtherApps]) ?? false
	}

	public func targetDescriptor() -> NSAppleEventDescriptor? {

		// Requires that the app has previously been launched.

		updateStatus()
		guard let runningApplication = runningApplication, !runningApplication.isTerminated else {
			return nil
		}

		return NSAppleEventDescriptor(runningApplication: runningApplication)
	}
}



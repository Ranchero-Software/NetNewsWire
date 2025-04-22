//
//  NSWorkspace+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 9/3/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public extension NSWorkspace {

	/// Get the file path to the default app for a given scheme such as "feed:"
	func defaultApp(forURLScheme scheme: String) -> String? {
		guard let url = URL(string: scheme) else {
			return nil
		}
		return urlForApplication(toOpen: url)?.path
	}

	/// Get the bundle ID for the default app for a given scheme such as "feed:"
	func defaultAppBundleID(forURLScheme scheme: String) -> String? {
		guard let path = defaultApp(forURLScheme: scheme) else {
			return nil
		}
		return bundleID(for: path)
	}

	/// Set the file path that should be the default app for a given scheme such as "feed:"
	/// It really just uses the bundle ID for the app, so there’s no guarantee that the actual path will be respected later.
	/// (In other words, you can’t specify one app over another if they have the same bundle ID.)
	@discardableResult
	func setDefaultApp(forURLScheme scheme: String, to path: String) -> Bool {
		guard let bundleID = bundleID(for: path) else {
			return false
		}
		return setDefaultAppBundleID(forURLScheme: scheme, to: bundleID)
	}

	/// Set the bundle ID for the app that should be default for a given scheme such as "feed:"
	@discardableResult
	func setDefaultAppBundleID(forURLScheme scheme: String, to bundleID: String) -> Bool {
		return LSSetDefaultHandlerForURLScheme(scheme as CFString, bundleID as CFString) == noErr
	}

	/// Get the file paths to apps that can handle a given scheme such as "feed:"
	func apps(forURLScheme scheme: String) -> Set<String> {
		guard let url = URL(string: scheme) else {
			return Set<String>()
		}
		guard let appURLs = LSCopyApplicationURLsForURL(url as CFURL, .viewer)?.takeRetainedValue() as [AnyObject]? else {
			return Set<String>()
		}
		let appPaths = appURLs.compactMap { (item) -> String? in
			guard let url = item as? URL else {
				return nil
			}
			return url.path
		}
		return Set(appPaths)
	}

	/// Get the bundle IDs for apps that can handle a given scheme such as "feed:"
	func bundleIDsForApps(forURLScheme scheme: String) -> Set<String> {
		let appPaths = apps(forURLScheme: scheme)
		let bundleIDs = appPaths.compactMap { (path) -> String? in
			return bundleID(for: path)
		}
		return Set(bundleIDs)
	}

	/// Get the bundle ID for an app at a path.
	func bundleID(for path: String) -> String? {
		return Bundle(path: path)?.bundleIdentifier
	}
}
#endif

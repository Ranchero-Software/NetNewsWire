//
//  MacWebBrowser.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

@MainActor public class MacWebBrowser {

	/// Opens a URL in the default browser.
	@discardableResult public class func openURL(_ url: URL, inBackground: Bool = false) -> Bool {

		guard let preparedURL = url.preparedForOpeningInBrowser() else {
			return false
		}

		if inBackground {

			let configuration = NSWorkspace.OpenConfiguration()
			configuration.activates = false
			NSWorkspace.shared.open(url, configuration: configuration, completionHandler: nil)

			return true
		}

		return NSWorkspace.shared.open(preparedURL)
	}

	/// Returns an array of the browsers installed on the system, sorted by name.
	///
	/// "Browsers" are applications that can both handle `https` URLs, and display HTML documents.
	public static func sortedBrowsers() -> [MacWebBrowser] {

		let httpsAppURLs = NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://apple.com/")!)
		let htmlAppURLs = NSWorkspace.shared.urlsForApplications(toOpen: UTType.html)
		let browserAppURLs = Set(httpsAppURLs).intersection(Set(htmlAppURLs))

		return browserAppURLs.compactMap { MacWebBrowser(url: $0) }.sorted {
			if let leftName = $0.name, let leftPath = $0.bundlePath, let rightName = $1.name, let rightPath = $1.bundlePath {
				return (leftName, leftPath) < (rightName, rightPath)
			}

			return false
		}
	}

	// Returns an array of browser names that have duplicates
	public static func duplicateBrowsersNames(in browsers: [MacWebBrowser]) -> [String?] {
		let duplicateBrowserNames = Dictionary(grouping: browsers, by: { $0.name })
			.filter { $1.count > 1 }
			.map { $0.key }

		return duplicateBrowserNames
	}

	public static func middleTruncPath(of url: URL) -> String {
		let pathComponents = url.pathComponents
		let ellipses = "…"
		let pathThreshold = 4

		// index 0 is `/` with absolute path
		let pathStart = "\(pathComponents[0])\(pathComponents[1])"

		// truncate middle with ellipses if path components exceed threshold
		if pathComponents.count > pathThreshold {
			let pathEnd = pathComponents[pathComponents.count - 2]
			return "\(pathStart)/\(ellipses)/\(pathEnd)"
		}

		return pathStart
	}

	/// The filesystem URL of the default web browser.
	private class var defaultBrowserURL: URL? {
		return NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://apple.com/")!)
	}

	/// The user's default web browser.
	public class var `default`: MacWebBrowser {
		return MacWebBrowser(url: defaultBrowserURL!)
	}

	/// The filesystem URL of the web browser.
	public let url: URL

	private lazy var _icon: NSImage? = {
		if let values = try? url.resourceValues(forKeys: [.effectiveIconKey]) {
			return values.effectiveIcon as? NSImage
		}

		return nil
	}()

	/// The application icon of the web browser.
	public var icon: NSImage? {
		return _icon
	}

	private lazy var _name: String? = {
		if let values = try? url.resourceValues(forKeys: [.localizedNameKey]), var name = values.localizedName {
			if let extensionRange = name.range(of: ".app", options: [.anchored, .backwards]) {
				name = name.replacingCharacters(in: extensionRange, with: "")
			}

			return name
		}

		return nil
	}()

	/// The localized name of the web browser, with any `.app` extension removed.
	public var name: String? {
		return _name
	}

	private lazy var _bundleIdentifier: String? = {
		return Bundle(url: url)?.bundleIdentifier
	}()

	/// The bundle identifier of the web browser (not unique if there are duplicate browsers)
	public var bundleIdentifier: String? {
		return _bundleIdentifier
	}

	private lazy var _bundlePath: String? = {
		return Bundle(url: url)?.bundlePath
	}()

	/// The bundle path of the web browser
	public var bundlePath: String? {
		return _bundlePath
	}

	/// Initializes a `MacWebBrowser` with a URL on disk.
	/// - Parameter url: The filesystem URL of the browser.
	public init(url: URL) {
		self.url = url
	}

	/// Initializes a `MacWebBrowser` from a bundle identifier.
	/// - Parameter bundleIdentifier: The bundle identifier of the browser.
	public convenience init?(bundleIdentifier: String) {
		guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
			return nil
		}

		self.init(url: url)
	}

	/// Opens a URL in this browser.
	/// - Parameters:
	///   - url: The URL to open.
	///   - inBackground: If `true`, attempt to load the URL without bringing the browser to the foreground.
	@discardableResult public func openURL(_ url: URL, inBackground: Bool = false) -> Bool {

		// TODO: make this function async.

		guard let preparedURL = url.preparedForOpeningInBrowser() else {
			return false
		}

		Task { @MainActor in

			let configuration = NSWorkspace.OpenConfiguration()
			if inBackground {
				configuration.activates = false
			}

			NSWorkspace.shared.open([preparedURL], withApplicationAt: self.url, configuration: configuration, completionHandler: nil)
		}

		return true
	}
}

extension MacWebBrowser: CustomDebugStringConvertible {

	public var debugDescription: String {
		if let name, let bundleIdentifier {
			return "MacWebBrowser: \(name) (\(bundleIdentifier))"
		} else {
			return "MacWebBrowser"
		}
	}
}

#endif

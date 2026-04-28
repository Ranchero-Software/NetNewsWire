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

@MainActor public final class MacWebBrowser {

	/// Opens a URL in the default browser.
	@discardableResult public static func openURL(_ url: URL, inBackground: Bool = false) -> Bool {

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

		return browserAppURLs.compactMap { MacWebBrowser(url: $0) }.sorted { left, right in
			guard let leftName = left.name, let rightName = right.name else {
				return false
			}
			let nameComparison = leftName.localizedCaseInsensitiveCompare(rightName)
			if nameComparison != .orderedSame {
				return nameComparison == .orderedAscending
			}
			let leftDisplay = MacWebBrowser.displayPath(of: left.url)
			let rightDisplay = MacWebBrowser.displayPath(of: right.url)
			return leftDisplay.localizedCaseInsensitiveCompare(rightDisplay) == .orderedAscending
		}
	}

	/// Returns set of duplicate browser names in an array of browsers.
	public static func duplicateBrowserNames(in browsers: [MacWebBrowser]) -> Set<String> {
		var browserNames = Set<String>()
		var duplicates = Set<String>()

		for browser in browsers {
			if let oneBrowserName = browser.name {
				if browserNames.contains(oneBrowserName) {
					duplicates.insert(oneBrowserName)
				}
				browserNames.insert(oneBrowserName)
			}
		}

		return duplicates
	}

	/// A short human-readable path for the parent directory of the browser at `url`,
	/// to use with duplicate browser names in a menu.
	///
	/// - Boot volume system path: `/Applications`
	/// - Boot volume user path: `/Users/brent/Applications`
	/// - Non-boot volume: leads with the volume name as Finder shows it, e.g.
	///   `/Macintosh HD/Applications` or `/Macintosh HD/Users/brent/Applications`.
	/// - Long interior paths are middle-truncated, e.g. `/Macintosh HD/…/Foo`.
	public static func displayPath(of url: URL) -> String {
		let parentPath = canonicalParentPath(for: url)
		return displayPath(forCanonicalParentPath: parentPath)
	}

	/// Pure formatting logic with no system dependencies, factored out for testing.
	/// `parentPath` is the firmlink-resolved parent directory of the browser bundle.
	static func displayPath(forCanonicalParentPath parentPath: String) -> String {
		let components = (parentPath as NSString).pathComponents

		// /Volumes/<volumeName>/<rest> — lead with the volume name.
		if components.count >= 3 && components[0] == "/" && components[1] == "Volumes" {
			let volumeName = components[2]
			let inside = components.dropFirst(3).joined(separator: "/")
			return composedVolumePath(volumeName: volumeName, inside: inside)
		}

		return shortenedRootPath(parentPath)
	}

	/// The user's default web browser.
	public static var `default`: MacWebBrowser {
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

private extension MacWebBrowser {

	/// Returns the parent directory of `url` resolved through `canonicalPathKey`.
	/// On modern macOS, this rewrites firmlink-alias mount points such as
	/// `/Volumes/Data/...` to the friendly form `/Volumes/<VolumeName>/...`.
	static func canonicalParentPath(for url: URL) -> String {
		let parent = url.deletingLastPathComponent().path
		let parentURL = URL(fileURLWithPath: parent)
		if let canonical = (try? parentURL.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath {
			return canonical
		}
		return parent
	}

	static func composedVolumePath(volumeName: String, inside: String) -> String {
		if inside.isEmpty {
			return "/\(volumeName)"
		}
		let parts = inside.split(separator: "/", omittingEmptySubsequences: true)
		if parts.count <= 3 {
			return "/\(volumeName)/\(inside)"
		}
		let trailing = String(parts.last ?? "")
		return "/\(volumeName)/…/\(trailing)"
	}

	static func shortenedRootPath(_ path: String) -> String {
		let components = (path as NSString).pathComponents
		let maxComponents = 4
		if components.count <= maxComponents {
			return path
		}
		let leading = "/\(components[1])"
		let trailing = components.last ?? ""
		return "\(leading)/…/\(trailing)"
	}

	/// The filesystem URL of the default web browser.
	static var defaultBrowserURL: URL? {
		NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://apple.com/")!)
	}
}

#endif

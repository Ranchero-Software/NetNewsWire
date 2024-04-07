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

		// TODO: make this function async

		guard let preparedURL = url.preparedForOpeningInBrowser() else {
			return false
		}

		if (inBackground) {

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
	public class func sortedBrowsers() -> [MacWebBrowser] {

		let httpsAppURLs = NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://apple.com/")!)
		let htmlAppURLs = NSWorkspace.shared.urlsForApplications(toOpen: UTType.html)
		let browserAppURLs = Set(httpsAppURLs).intersection(Set(htmlAppURLs))

		return browserAppURLs.compactMap { MacWebBrowser(url: $0) }.sorted {
			if let leftName = $0.name, let rightName = $1.name {
				return leftName < rightName
			}

			return false
		}
	}

	/// The filesystem URL of the default web browser.
	private class var defaultBrowserURL: URL? {
		return NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https:///")!)
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

	/// The bundle identifier of the web browser.
	public var bundleIdentifier: String? {
		return _bundleIdentifier
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

#endif

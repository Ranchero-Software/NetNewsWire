//
//  MacWebBrowser.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#if os(macOS)
import AppKit

public class MacWebBrowser {

	/// Opens a URL in the default browser.
	@discardableResult public class func openURL(_ url: URL, inBackground: Bool = false) -> Bool {
		
		guard let preparedURL = url.preparedForOpeningInBrowser() else {
			return false
		}
		
		if (inBackground) {
			do {
				try NSWorkspace.shared.open(preparedURL, options: [.withoutActivation], configuration: [:])
				return true
			}
			catch {
				return false
			}
		}
		
		return NSWorkspace.shared.open(preparedURL)
	}

	/// Returns an array of the browsers installed on the system, sorted by name.
	///
	/// "Browsers" are applications that can both handle `https` URLs, and display HTML documents.
	public class func sortedBrowsers() -> [MacWebBrowser] {
		guard let httpsIDs = LSCopyAllHandlersForURLScheme("https" as CFString)?.takeRetainedValue() as? [String] else {
			return []
		}

		guard let htmlIDs = LSCopyAllRoleHandlersForContentType(kUTTypeHTML, .viewer)?.takeRetainedValue() as? [String] else {
			return []
		}

		let browserIDs = Set(httpsIDs).intersection(Set(htmlIDs))

		return browserIDs.compactMap { MacWebBrowser(bundleIdentifier: $0) }.sorted {
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
		guard let preparedURL = url.preparedForOpeningInBrowser() else {
			return false
		}

		let options: NSWorkspace.LaunchOptions = inBackground ? [.withoutActivation] : []

		return NSWorkspace.shared.open([preparedURL], withAppBundleIdentifier: self.bundleIdentifier, options: options, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
	}

}

extension MacWebBrowser: CustomDebugStringConvertible {

	public var debugDescription: String {
		if let name = name, let bundleIdentifier = bundleIdentifier{
			return "MacWebBrowser: \(name) (\(bundleIdentifier))"
		} else {
			return "MacWebBrowser"
		}
	}
}

#endif

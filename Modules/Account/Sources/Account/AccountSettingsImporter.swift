//
//  AccountSettingsImporter.swift
//  Account
//
//  Created by Brent Simmons on 3/6/26.
//

import Foundation
import os
import RSWeb

/// One-time import from a Settings.plist into UserDefaults.
@MainActor struct AccountSettingsImporter {

	struct ImportedSettings {
		let name: String?
		let isActive: Bool?
		let username: String?
		let lastArticleFetchStartTime: Date?
		let lastRefreshCompletedDate: Date?
		let endpointURL: URL?
		let externalID: String?
		let conditionalGetInfo: [String: HTTPConditionalGetInfo]?
	}

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AccountSettingsImporter")

	/// Returns ImportedSettings if there is a Settings.plist to read.
	/// Returns nil if there is no plist or it can't be read.
	static func readSettingsFromPlist(accountID: String, dataFolder: String) -> ImportedSettings? {
		let plistPath = (dataFolder as NSString).appendingPathComponent("Settings.plist")
		guard FileManager.default.fileExists(atPath: plistPath) else {
			return nil
		}

		Self.logger.info("AccountSettingsImporter: importing Settings.plist for account \(accountID)")

		guard let data = FileManager.default.contents(atPath: plistPath) else {
			Self.logger.error("AccountSettingsImporter: unable to read Settings.plist for account \(accountID)")
			return nil
		}

		guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
			Self.logger.error("AccountSettingsImporter: unable to deserialize Settings.plist for account \(accountID)")
			return nil
		}

		var conditionalGetInfoDict: [String: HTTPConditionalGetInfo]?
		if let rawDict = plist["conditionalGetInfo"] as? [String: [String: String]] {
			var dict = [String: HTTPConditionalGetInfo]()
			for (endpoint, value) in rawDict {
				let lastModified = value["lastModified"]
				let etag = value["etag"]
				if let info = HTTPConditionalGetInfo(lastModified: lastModified, etag: etag) {
					dict[endpoint] = info
				}
			}
			if !dict.isEmpty {
				conditionalGetInfoDict = dict
			}
		}

		var endpointURL: URL?
		if let urlString = plist["endpointURL"] as? String {
			endpointURL = URL(string: urlString)
		} else if let urlDict = plist["endpointURL"] as? [String: String] {
			// PropertyListEncoder encodes URL as ["relative": "…", "base": "…"]
			let relative = urlDict["relative"]
			let base = urlDict["base"]
			let baseURL: URL? = {
				guard let base else {
					return nil
				}
				return URL(string: base)
			}()

			if let baseURL, let relative {
				endpointURL = URL(string: relative, relativeTo: baseURL)
			} else if let relative {
				endpointURL = URL(string: relative)
			} else if let baseURL {
				endpointURL = baseURL
			}
		}

		Self.logger.info("AccountSettingsImporter: finished importing Settings.plist for account \(accountID)")

		return ImportedSettings(
			name: plist["name"] as? String,
			isActive: plist["isActive"] as? Bool,
			username: plist["username"] as? String,
			lastArticleFetchStartTime: plist["lastArticleFetch"] as? Date,
			lastRefreshCompletedDate: plist["lastArticleFetchEndTime"] as? Date,
			endpointURL: endpointURL,
			externalID: plist["externalID"] as? String,
			conditionalGetInfo: conditionalGetInfoDict
		)
	}
}

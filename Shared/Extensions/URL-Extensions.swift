//
//  URL-Extensions.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 03/05/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

extension URL {
	
	/// Extracts email address from a `URL` with a `mailto` scheme, otherwise `nil`.
	var emailAddress: String? {
		scheme == "mailto" ? URLComponents(url: self, resolvingAgainstBaseURL: false)?.path : nil
	}
	
	/// URL pointing to current app version release notes.
	static var releaseNotes: URL {
		let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
		var gitHub = "https://github.com/Ranchero-Software/NetNewsWire/releases/tag/"
		#if os(macOS)
		gitHub += "mac-\(String(describing: appVersion))"
		return URL(string: gitHub)!
		#else
		gitHub += "ios-\(String(describing: appVersion))"
		return URL(string: gitHub)!
		#endif
	}
	
	func valueFor(_ parameter: String) -> String? {
		guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
			  let queryItems = components.queryItems,
			  let value = queryItems.first(where: { $0.name == parameter })?.value else {
			return nil
		}
		return value
		
	}
}

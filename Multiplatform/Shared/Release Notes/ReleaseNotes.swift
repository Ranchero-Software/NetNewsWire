//
//  ReleaseNotes.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 13/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

struct ReleaseNotes {
	
	var url: URL {
		var gitHub = "https://github.com/Ranchero-Software/NetNewsWire/releases/tag/"
		#if os(macOS)
		gitHub += "mac-\(String(describing: versionString()))"
		return URL(string: gitHub)!
		#else
		gitHub += "ios-\(String(describing: versionString()))-\(String(describing: buildVersionString()))"
		return URL(string: gitHub)!
		#endif
	}
	
	private func versionString() -> String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
	}
	
	private func buildVersionString() -> String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
	}
 
}

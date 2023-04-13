//
//  WKUserContentController-Extensions.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/5/23.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

extension WKUserContentController {
	
	func addUserScript(forResource res: String, withExtension ext: String) {
		if let url = Bundle.main.url(forResource: res, withExtension: ext), let source = try? String(contentsOf: url) {
			let userScript = WKUserScript(source: source, injectionTime: WKUserScriptInjectionTime.atDocumentStart, forMainFrameOnly: false)
			addUserScript(userScript)
		}
	}
	
}

//
//  WrapperScriptMessageHandler.swift
//  Multiplatform iOS
//
//  Created by Maurice Parker on 7/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

class WrapperScriptMessageHandler: NSObject, WKScriptMessageHandler {
	
	// We need to wrap a message handler to prevent a circlular reference
	private weak var handler: WKScriptMessageHandler?
	
	init(_ handler: WKScriptMessageHandler) {
		self.handler = handler
	}
	
	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		handler?.userContentController(userContentController, didReceive: message)
	}
	
}

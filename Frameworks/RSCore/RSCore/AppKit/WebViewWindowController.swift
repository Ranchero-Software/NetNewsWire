//
//  WebViewWindowController.swift
//  RSCore
//
//  Created by Brent Simmons on 11/13/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Cocoa
import WebKit

public final class WebViewWindowController: NSWindowController {

	@IBOutlet private var webview: WKWebView!
	private var title: String!

	public convenience init(title: String) {

		self.init(windowNibName: NSNib.Name(rawValue: "WebViewWindow"))
		self.title = title
	}

	public override func windowDidLoad() {

		window!.title = title
	}
}

//
//  CreditsNetNewsWireView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 03/10/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import WebKit
import Html
 
@available(macOS 12, *)
struct WebView: NSViewRepresentable {

	var htmlString: String
 
	func makeNSView(context: Context) -> WKWebView {
		let view = WKWebView()
		view.loadHTMLString(htmlString, baseURL: nil)
		return view
	}
 
	func updateNSView(_ webView: WKWebView, context: Context) {
		
	}
}

@available(macOS 12, *)
struct CreditsNetNewsWireView: View, LoadableAboutData {
	var body: some View {
		VStack {
			Image("About")
				.resizable()
				.frame(width: 75, height: 75)
			
			Text(verbatim: "NetNewsWire")
				.font(.headline)
			
			Text("\(Bundle.main.versionNumber) (\(Bundle.main.buildNumber))")
				.foregroundColor(.secondary)
				.font(.callout)
			
			Text("label.text.netnewswire-byline", comment: "By Brent Simmons and the NetNewsWire team.")
				.font(.subheadline)
			
			Text("label.markdown.netnewswire-website", comment: "Markdown formatted link to netnewswire.com")
				.font(.callout)
			
			WebView(htmlString: AboutHTML().renderedDocument())
		}
		
		.frame(width: 500, height: 700)
	}
	
}

@available(macOS 12, *)
struct CreditsNetNewsWireView_Previews: PreviewProvider {
    static var previews: some View {
        CreditsNetNewsWireView()
    }
}

//
//  AboutNewNewsWireView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 03/10/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import WebKit
import Html
 
@available(macOS 12, *)
fileprivate struct WebView: NSViewRepresentable {

	var htmlString: String
 
	func makeNSView(context: Context) -> DetailWebView {
		let view = DetailWebView()
		view.loadHTMLString(htmlString, baseURL: nil)
		return view
	}
 
	func updateNSView(_ webView: DetailWebView, context: Context) {
		webView.navigationDelegate = context.coordinator
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	class Coordinator: NSObject, WKNavigationDelegate {
		
		var parent: WebView!
		
		init(_ parent: WebView) {
			self.parent = parent
		}
		
		func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
			if navigationAction.navigationType == .linkActivated {
				if let url = navigationAction.request.url {
					Task { @MainActor in Browser.open(url.absoluteString) }
				}
				decisionHandler(.cancel)
				return
			}
			decisionHandler(.allow)
		}
	}
}

@available(macOS 12, *)
struct AboutNewNewsWireView: View, LoadableAboutData {
	var body: some View {
		VStack(spacing: 4) {
			
			Image("About")
				.resizable()
				.frame(width: 70, height: 70)
				.padding(.top)
			
			Text(verbatim: "NetNewsWire")
				.font(.title3)
				.bold()
				
			Text("\(Bundle.main.versionNumber) (\(Bundle.main.buildNumber))")
				.font(.body)
				.padding(.bottom)
			
			WebView(htmlString: AboutHTML().renderedDocument())
				.overlay(Divider(), alignment: .top)
				.overlay(Divider(), alignment: .bottom)
				
			HStack(alignment: .center) {
				Spacer()
				Text(verbatim: "Copyright © Brent Simmons 2002 - \(Calendar.current.component(.year, from: .now))")
					.font(.caption2)
					.padding(.bottom, 6)
					.padding(.top, 2)
				Spacer()
			}
		}
		.frame(width: 425, height: 550)
	}
}

@available(macOS 12, *)
struct AboutNetNewsWireView_Previews: PreviewProvider {
    static var previews: some View {
        AboutNewNewsWireView()
    }
}

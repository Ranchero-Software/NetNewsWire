//
//  SafariView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 16/6/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import SafariServices

struct SafariView : UIViewControllerRepresentable {
	
	let url: URL
	
	func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
		let safari = SFSafariViewController(url: url)
		safari.delegate = context.coordinator
		return safari
	}
	
	func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
		//
	}
	
	func makeCoordinator() -> Coordinator {
		return Coordinator(self)
	}
	
	class Coordinator : NSObject, SFSafariViewControllerDelegate {
		var parent: SafariView
		
		init(_ safariView: SafariView) {
			self.parent = safariView
		}
		
		// MARK: SFSafariViewControllerDelegate
		func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
			
		}
		
		func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {
			
		}
		
		func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
			
		}
	}
}



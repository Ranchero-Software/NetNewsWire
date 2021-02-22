//
//  SafariView.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 30/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import SafariServices


private final class Safari: UIViewControllerRepresentable {
	
	var urlToLoad: URL
	
	init(url: URL) {
		self.urlToLoad = url
	}
	
	func makeUIViewController(context: Context) -> SFSafariViewController {
		let viewController = SFSafariViewController(url: urlToLoad)
		viewController.delegate = context.coordinator
		return viewController
	}
	
	func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
		
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	class Coordinator: NSObject, SFSafariViewControllerDelegate {
		var parent: Safari
			
		init(_ parent: Safari) {
			self.parent = parent
		}
		
		func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
			
		}
		
	}
	
}

struct SafariView: View {
    
	var url: URL
	
	var body: some View {
        Safari(url: url)
    }
}

struct SafariView_Previews: PreviewProvider {
    static var previews: some View {
		SafariView(url: URL(string: "https://netnewswire.com/")!)
    }
}

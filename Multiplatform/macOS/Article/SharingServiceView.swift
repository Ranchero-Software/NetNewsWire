//
//  SharingServiceView.swift
//  Multiplatform macOS
//
//  Created by Maurice Parker on 7/14/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import AppKit
import Articles

class SharingServiceController: NSViewController {
	
	var sharingServicePickerDelegate: SharingServicePickerDelegate? = nil
	var articles = [Article]()
	var completion: (() -> Void)? = nil

	override func loadView() {
		view = NSView()
	}
	
	override func viewDidAppear() {
		guard let anchor = view.superview?.superview else { return }
		
		sharingServicePickerDelegate = SharingServicePickerDelegate(self.view.window, completion: completion)
		
		let sortedArticles = articles.sortedByDate(.orderedAscending)
		let items = sortedArticles.map { ArticlePasteboardWriter(article: $0) }
		
		let sharingServicePicker = NSSharingServicePicker(items: items)
		sharingServicePicker.delegate = sharingServicePickerDelegate
		
		sharingServicePicker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
	}
	
}

struct SharingServiceView: NSViewControllerRepresentable {

	var articles: [Article]
	@Binding var showing: Bool
	
	func makeNSViewController(context: Context) -> SharingServiceController {
		let controller = SharingServiceController()
		controller.articles = articles
		controller.completion = {
			showing = false
		}
		return controller
	}

	func updateNSViewController(_ nsViewController: SharingServiceController, context: Context) {
	}
	
}

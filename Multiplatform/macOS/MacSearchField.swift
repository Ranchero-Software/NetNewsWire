//
//  MacSearchField.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 29/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import SwiftUI


final class MacSearchField: NSViewRepresentable {

	typealias NSViewType = NSSearchField
	
	
	func makeNSView(context: Context) -> NSSearchField {
		let searchField = NSSearchField()
		searchField.delegate = context.coordinator
		return searchField
	}
	
	func updateNSView(_ nsView: NSSearchField, context: Context) {
		
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	class Coordinator: NSObject, NSSearchFieldDelegate {
		var parent: MacSearchField
		
		init(_ parent: MacSearchField) {
			self.parent = parent
		}
		
		func searchFieldDidStartSearching(_ sender: NSSearchField) {
			//
		}
		
		func searchFieldDidEndSearching(_ sender: NSSearchField) {
			//
		}
		
	}
	
}

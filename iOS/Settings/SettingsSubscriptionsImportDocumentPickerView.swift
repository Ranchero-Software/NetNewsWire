//
//  SettingsSubscriptionsImportDocumentPickerView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsSubscriptionsImportDocumentPickerView : UIViewControllerRepresentable {
	var account: Account
	
	func makeUIViewController(context: UIViewControllerRepresentableContext<SettingsSubscriptionsImportDocumentPickerView>) -> UIDocumentPickerViewController {
		let docPicker = UIDocumentPickerViewController(documentTypes: ["public.xml", "org.opml.opml"], in: .import)
		docPicker.delegate = context.coordinator
		return docPicker
	}
	
	func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: UIViewControllerRepresentableContext<SettingsSubscriptionsImportDocumentPickerView>) {
		//
	}
	
	func makeCoordinator() -> Coordinator {
		return Coordinator(self)
	}
	
	class Coordinator : NSObject, UIDocumentPickerDelegate {
		var parent: SettingsSubscriptionsImportDocumentPickerView
		
		init(_ view: SettingsSubscriptionsImportDocumentPickerView) {
			self.parent = view
		}
		
		func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
			for url in urls {
				parent.account.importOPML(url) { result in}
			}
		}
		
	}
}

//
//  SettingsImportSubscriptionsDocumentPickerView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsImportSubscriptionsDocumentPickerView : UIViewControllerRepresentable {
	var account: Account?
	
	func makeUIViewController(context: UIViewControllerRepresentableContext<SettingsImportSubscriptionsDocumentPickerView>) -> UIDocumentPickerViewController {
		let docPicker = UIDocumentPickerViewController(documentTypes: ["public.xml", "org.opml.opml"], in: .import)
		docPicker.delegate = context.coordinator
		docPicker.modalPresentationStyle = .formSheet
		return docPicker
	}
	
	func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: UIViewControllerRepresentableContext<SettingsImportSubscriptionsDocumentPickerView>) {
		//
	}
	
	func makeCoordinator() -> Coordinator {
		return Coordinator(self)
	}
	
	class Coordinator : NSObject, UIDocumentPickerDelegate {
		var parent: SettingsImportSubscriptionsDocumentPickerView
		
		init(_ view: SettingsImportSubscriptionsDocumentPickerView) {
			self.parent = view
		}
		
		func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
			for url in urls {
				parent.account?.importOPML(url) { result in}
			}
		}
		
	}
}

#if DEBUG
struct SettingsImportSubscriptionsDocumentPickerView_Previews : PreviewProvider {
    static var previews: some View {
        SettingsImportSubscriptionsDocumentPickerView()
    }
}
#endif

//
//  SettingsSubscriptionsExportDocumentPickerView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsSubscriptionsExportDocumentPickerView : UIViewControllerRepresentable {
	var account: Account

	func makeUIViewController(context: UIViewControllerRepresentableContext<SettingsSubscriptionsExportDocumentPickerView>) ->   UIDocumentPickerViewController {
		
		let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
		let filename = "Subscriptions-\(accountName).opml"
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		
		let opmlString = OPMLExporter.OPMLString(with: account, title: filename)
		try? opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
		
		return UIDocumentPickerViewController(url: tempFile, in: .exportToService)
	}
	
	func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: UIViewControllerRepresentableContext<SettingsSubscriptionsExportDocumentPickerView>) {
		//
	}
	
}

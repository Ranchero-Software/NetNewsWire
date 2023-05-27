//
//  CloudKitAddAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 16/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct CloudKitAddAccountView: View {
    
	@Environment(\.dismiss) private var dismiss
	@State private var accountError: (Error?, Bool) = (nil, false)
	
	var body: some View {
		NavigationView {
			Form {
				AccountSectionHeader(accountType: .cloudKit)
				Section { createCloudKitAccount }
				Section(footer: cloudKitExplainer) {}
			}
			.navigationTitle(Text(verbatim: "iCloud"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button(action: { dismiss() }, label: { Text("Cancel", comment: "Button title") })
				}
			}
			.alert(Text("Error", comment: "Alert title: Error"), isPresented: $accountError.1) {
				Button(action: {}, label: { Text("Dismiss", comment: "Button title") })
			} message: {
				Text(accountError.0?.localizedDescription ?? "Unknown Error")
			}
			.dismissOnExternalContextLaunch()
			.dismissOnAccountAdd()
		}
    }
	
	var createCloudKitAccount: some View {
		Button {
			guard FileManager.default.ubiquityIdentityToken != nil else {
				accountError = (LocalizedNetNewsWireError.iCloudDriveMissing, true)
				return
			}
			let _ = AccountManager.shared.createAccount(type: .cloudKit)
		} label: {
			HStack {
				Spacer()
				Text("Use iCloud", comment: "Button title")
				Spacer()
			}
		}
	}
	
	var cloudKitExplainer: some View {
		VStack(spacing: 4) {
			if !AccountManager.shared.accounts.contains(where: { $0.type == .cloudKit }) {
				// The explainer is only shown when a CloudKit account doesn't exist.
				Text("NetNewsWire will use your iCloud account to sync your subscriptions across your Mac and iOS devices.", comment: "iCloud account explanatory text")
			}
			Text("[iCloud Syncing Limitations & Solutions](https://netnewswire.com/help/iCloud)", comment: "Link which opens webpage describing iCloud syncing limitations.")
		}.multilineTextAlignment(.center)
	}
	
	
}

struct iCloudAccountView_Previews: PreviewProvider {
    static var previews: some View {
        CloudKitAddAccountView()
    }
}

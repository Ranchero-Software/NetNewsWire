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
	@State private var addAccountError: (LocalizedError?, Bool) = (nil, false)
	
	var body: some View {
		NavigationView {
			Form {
				Section(header: cloudKitHeader) {}
				Section { createCloudKitAccount }
				Section(footer: cloudKitExplainer) {}
			}
			.navigationTitle(Text("CLOUDKIT", tableName: "Account"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button(action: { dismiss() }, label: { Text("CANCEL_BUTTON_TITLE", tableName: "Buttons") })
				}
			}
			.alert(Text("ERROR_TITLE", tableName: "Errors"), isPresented: $addAccountError.1) {
				Button(action: {}, label: { Text("DISMISS_BUTTON_TITLE", tableName: "Buttons") })
			} message: {
				Text(addAccountError.0?.localizedDescription ?? "Unknown Error")
			}
			.onReceive(NotificationCenter.default.publisher(for: .UserDidAddAccount)) { _ in
				dismiss()
			}
		}
    }
	
	var cloudKitHeader: some View {
		HStack {
			Spacer()
			Image(uiImage: AppAssets.accountCloudKitImage)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 48, height: 48)
			Spacer()
		}
	}
	
	var createCloudKitAccount: some View {
		Button {
			guard FileManager.default.ubiquityIdentityToken != nil else {
				addAccountError = (LocalizedNetNewsWireError.iCloudDriveMissing, true)
				return
			}
			let _ = AccountManager.shared.createAccount(type: .cloudKit)
		} label: {
			HStack {
				Spacer()
				Text("USE_CLOUDKIT_BUTTON_TITLE", tableName: "Buttons")
				Spacer()
			}
		}
	}
	
	var cloudKitExplainer: some View {
		VStack(spacing: 4) {
			if !AccountManager.shared.accounts.contains(where: { $0.type == .cloudKit }) {
				// The explainer is only shown when a CloudKit account doesn't exist.
				Text("CLOUDKIT_FOOTER_EXPLAINER", tableName: "Account") 
			}
			Text("CLOUDKIT_LIMITATIONS_TITLE", tableName: "Inspector")
		}.multilineTextAlignment(.center)
	}
	
	
}

struct iCloudAccountView_Previews: PreviewProvider {
    static var previews: some View {
        CloudKitAddAccountView()
    }
}

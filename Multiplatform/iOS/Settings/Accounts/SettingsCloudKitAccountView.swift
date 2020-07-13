//
//  SettingsCloudKitAccountView.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 13/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsCloudKitAccountView: View {
	@Environment(\.presentationMode) var presentationMode

	var body: some View {
		NavigationView {
			List {
				Section(header: AccountHeaderImageView(image: AppAssets.image(for: .cloudKit)!)) { }
				Section {
					HStack {
						Spacer()
						Button(action: { self.addAccount() }) {
							Text("Add Account")
						}
						Spacer()
					}
				}
			}
			.listStyle(InsetGroupedListStyle())
			.navigationBarTitle(Text(verbatim: "iCloud"), displayMode: .inline)
			.navigationBarItems(leading: Button(action: { self.dismiss() }) { Text("Cancel") } )
		}
	}

	private func addAccount() {
		_ = AccountManager.shared.createAccount(type: .cloudKit)
		dismiss()
	}

	private func dismiss() {
		presentationMode.wrappedValue.dismiss()
	}
}

struct SettingsCloudKitAccountView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsCloudKitAccountView()
    }
}

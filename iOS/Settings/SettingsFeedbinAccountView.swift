//
//  SettingsFeedbinAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SettingsFeedbinAccountView : View {
	@State var email: String
	@State var password: String

	var body: some View {
		NavigationView {
			List {
				Section(header:
					SettingsAccountLabelView(accountImage: "accountFeedbin", accountLabel: "Feedbin").padding()
				)  {
					HStack {
						Spacer()
						TextField($email, placeholder: Text("Email"))
						Spacer()
					}
					HStack {
						Spacer()
						SecureField($password, placeholder: Text("Password"))
						Spacer()
					}
				}
				Section {
					HStack {
						Spacer()
						Button(action: {}) {
							Text("Add Account")
						}
						Spacer()
					}
				}
			}
			.listStyle(.grouped)
			.navigationBarTitle(Text(""), displayMode: .inline)
		}
	}
	
}

#if DEBUG
struct SettingsFeedbinAccountView_Previews : PreviewProvider {
    static var previews: some View {
        SettingsFeedbinAccountView(email: "", password: "")
    }
}
#endif

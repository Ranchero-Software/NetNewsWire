//
//  SettingsAddAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SettingsAddAccountView : View {
    var body: some View {
		List {
			PresentationButton(SettingsAccountLabelView(accountImage: "accountLocal", accountLabel: "On My Device"),
							   destination: SettingsLocalAccountView(name: ""))
			PresentationButton(SettingsAccountLabelView(accountImage: "accountFeedbin", accountLabel: "Feedbin"),
							   destination: SettingsFeedbinAccountView(viewModel: SettingsFeedbinAccountView.ViewModel()))
		}
		.listStyle(.grouped)
		.navigationBarTitle(Text("Add Account"), displayMode: .inline)
	}
}

#if DEBUG
struct AddAccountView_Previews : PreviewProvider {
    static var previews: some View {
        SettingsAddAccountView()
    }
}
#endif

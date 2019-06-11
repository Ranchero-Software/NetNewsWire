//
//  SettingsAccountLabelView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SettingsAccountLabelView : View {
	let accountImage: String
	let accountLabel: String
	
    var body: some View {
		HStack {
			Spacer()
			HStack {
				Image(accountImage)
					.resizable()
					.aspectRatio(1, contentMode: .fit)
					.frame(height: 32)
				Text(verbatim: accountLabel).font(.title)

			}
			.layoutPriority(1)
			Spacer()
		}
		.foregroundColor(.primary)
	}
}

#if DEBUG
struct SettingsAccountLabelView_Previews : PreviewProvider {
    static var previews: some View {
        SettingsAccountLabelView(accountImage: "accountLocal", accountLabel: "On My Device")
			.previewLayout(.fixed(width: 300, height: 44))
    }
}
#endif

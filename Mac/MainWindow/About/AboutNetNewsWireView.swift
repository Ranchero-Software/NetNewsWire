//
//  AboutNetNewsWireView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 03/10/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI

@available(macOS 12, *)
struct AboutNetNewsWireView: View {
	var body: some View {
		HStack {
			Spacer()
			VStack(spacing: 8) {
				Spacer()

				Image("About")
					.resizable()
					.frame(width: 75, height: 75)
				
				Text("NetNewsWire")
					.font(.headline)
				
				Text("\(Bundle.main.versionNumber) (\(Bundle.main.buildNumber))")
					.foregroundColor(.secondary)
					.font(.callout)
				
				Text("By Brent Simmons and the NetNewsWire team.")
					.font(.subheadline)
				
				Text("[netnewswire.com](https://netnewswire.com)")
					.font(.callout)
				
				Spacer()
				
				Text(verbatim: "Copyright © Brent Simmons 2002 - \(Calendar.current.component(.year, from: .now))")
					.font(.callout)
					.foregroundColor(.secondary)
					.padding(.bottom)
			}
			Spacer()
		}
		.multilineTextAlignment(.center)
	}
}

@available(macOS 12, *)
struct AboutNetNewsWireView_Previews: PreviewProvider {
    static var previews: some View {
        AboutNetNewsWireView()
    }
}

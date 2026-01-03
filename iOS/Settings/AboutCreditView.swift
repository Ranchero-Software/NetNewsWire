//
//  AboutCreditView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 15/09/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import SwiftUI

struct AboutCreditView: View {
	
	let contributorType: String
	let contributors: [Contributors]
	
    var body: some View {
		HStack(alignment: .top) {
			Spacer()
			Text(verbatim: contributorType)
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, alignment: .trailing)
				.lineLimit(3)
				.multilineTextAlignment(.trailing)
				.minimumScaleFactor(0.8)
			VStack {
				ForEach(contributors, id: \.self) { item in
					Text(verbatim: item.contributor.name)
						.frame(maxWidth: .infinity, alignment: .leading)
						.lineLimit(2)
						.multilineTextAlignment(.leading)
						.minimumScaleFactor(0.8)
						.foregroundStyle(.link)
						.onTapGesture {
							UIApplication.shared.open(item.contributor.url)
						}
				}
			}
			Spacer()
		}
		
    }
}

#Preview {
	AboutCreditView(contributorType: "Contributing Developers", contributors: [Contributors.mauriceParker, Contributors.stuartBreckenridge])
}

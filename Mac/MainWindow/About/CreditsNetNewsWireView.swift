//
//  CreditsNetNewsWireView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 03/10/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI

@available(macOS 12, *)
struct CreditsNetNewsWireView: View, LoadableAboutData {
	var body: some View {
		ScrollView(.vertical, showsIndicators: false) {
			Spacer()
				.frame(height: 12)
			Section("Primary Contributors") {
				GroupBox {
					ForEach(0..<about.PrimaryContributors.count, id: \.self) { i in
						contributorView(about.PrimaryContributors[i])
							.padding(.vertical, 2)
							.listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
					}
				}
				
			}
			
			Section("Additional Contributors") {
				GroupBox {
					ForEach(0..<about.AdditionalContributors.count, id: \.self) { i in
						contributorView(about.AdditionalContributors[i])
							.padding(.vertical, 2)
							.listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
					}
				}
				
			}
			
			Section("Thanks") {
				GroupBox {
					Text(about.ThanksMarkdown)
						.multilineTextAlignment(.center)
						.font(.callout)
						.padding(.vertical, 2)
				}
				
			}
			Spacer()
				.frame(height: 12)
		}
		.padding(.horizontal)
		.frame(width: 400, height: 400)
	}
	
	func contributorView(_ appCredit: AboutData.Contributor) -> some View {
		HStack {
			Text(appCredit.name)
			Spacer()
			if let role = appCredit.role {
				Text(role)
					.foregroundColor(.secondary)
			}
			Image(systemName: "info.circle")
				.foregroundColor(.secondary)
		}
		.onTapGesture {
			guard let url = appCredit.url else { return }
			if let _ = URL(string: url) {
				Task { @MainActor in
					Browser.open(url, inBackground: false)
				}
			}
		}
	}
}

@available(macOS 12, *)
struct CreditsNetNewsWireView_Previews: PreviewProvider {
    static var previews: some View {
        CreditsNetNewsWireView()
    }
}

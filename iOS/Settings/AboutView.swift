//
//  AboutView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 02/10/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI

struct AboutView: View, LoadableAboutData {
    
	var body: some View {
		List {
			Section(header: aboutHeaderView) {}
			Section(header: Text("Primary Contributors")) {
				ForEach(0..<about.PrimaryContributors.count, id: \.self) { i in
					contributorView(about.PrimaryContributors[i])
				}
			}
			Section(header: Text("Additional Contributors")) {
				ForEach(0..<about.AdditionalContributors.count, id: \.self) { i in
					contributorView(about.AdditionalContributors[i])
				}
			}
			Section(header: Text("Thanks"), footer: thanks, content: {})
			Section(footer: copyright, content: {})
		}
		.listStyle(.insetGrouped)
		.navigationTitle(Text("About"))
		.navigationBarTitleDisplayMode(.inline)
    }
	
	var aboutHeaderView: some View {
		HStack {
			Spacer()
			VStack(alignment: .center, spacing: 8) {
				Image("About")
					.resizable()
					.frame(width: 75, height: 75)
				
				Text(Bundle.main.appName)
					.font(.headline)
				
				Text("\(Bundle.main.versionNumber) (\(Bundle.main.buildNumber))")
					.foregroundColor(.secondary)
					.font(.callout)
					
				Text("By Brent Simmons and the Ranchero Software team.")
					.font(.subheadline)
				
				Text("[netnewswire.com](https://netnewswire.com)")
					
			}
			Spacer()
		}
		.textCase(.none)
		.multilineTextAlignment(.center)
	}
	
	func contributorView(_ appCredit: AboutData.Contributor) -> some View {
		HStack {
			Text(appCredit.name)
			Spacer()
			if let role = appCredit.role {
				Text(role)
					.font(.callout)
					.foregroundColor(.secondary)
			}
			if let _ = appCredit.url {
				Image(systemName: "info.circle")
					.foregroundColor(.secondary)
			}
		}
		.onTapGesture {
			guard let url = appCredit.url else { return }
			if let creditURL = URL(string: url) {
				UIApplication.shared.open(creditURL)
			}
		}
	}
	
	
	var thanks: some View {
		Text(about.ThanksMarkdown)
			.multilineTextAlignment(.center)
			.font(.callout)
	}
	
	var copyright: some View {
		HStack {
			Spacer()
			Text(verbatim: "Copyright © Brent Simmons 2002 - \(Calendar.current.component(.year, from: .now))")
			Spacer()
		}	
	}
	
}


struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
		NavigationView {
			AboutView()
		}
    }
}

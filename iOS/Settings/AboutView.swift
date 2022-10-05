//
//  AboutView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 02/10/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI

struct AboutView: View {
    
	private var about: AboutData!
	
	init() {
		guard let path = Bundle.main.path(forResource: "About", ofType: "plist") else {
			fatalError("The about plist really should exist.")
		}
		let url = URL(fileURLWithPath: path)
		let data = try! Data(contentsOf: url)
		about = try! PropertyListDecoder().decode(AboutData.self, from: data)
	}
	
	var body: some View {
		List {
			Section(header: aboutHeaderView) {}
			Section(header: Text("Credits")) {
				ForEach(0..<about.AppCredits.count, id: \.self) { i in
					creditView(about.AppCredits[i])
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
					
				Text("By Brent Simmons and the Ranchero Software team.")
					.font(.subheadline)
				
				Text("[netnewswire.com](https://netnewswire.com)")
					
			}
			Spacer()
		}
		.textCase(.none)
		.multilineTextAlignment(.center)
	}
	
	func creditView(_ appCredit: AboutData.AppCredit) -> some View {
		HStack {
			Text(appCredit.role)
			Spacer()
			Text(appCredit.name)
				.foregroundColor(.secondary)
		}
		.onTapGesture {
			guard let url = appCredit.url else { return }
			if let creditURL = URL(string: url) {
				UIApplication.shared.open(creditURL)
			}
		}
	}
	
	func contributorView(_ contributor: AboutData.Contributor) -> some View {
		HStack {
			Text(contributor.name)
			Spacer()
		}
		.onTapGesture {
			guard let url = contributor.url else { return }
			if let contributorURL = URL(string: url) {
				UIApplication.shared.open(contributorURL)
			}
		}
	}
	
	var thanks: some View {
		Text(about.ThanksMarkdown)
			.multilineTextAlignment(.center)
			.font(.callout)
	}
	
	var copyright: some View {
		Text(verbatim: "Copyright © Brent Simmons 2002 - \(Calendar.current.component(.year, from: .now))")
	}
	
}


struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
		NavigationView {
			AboutView()
		}
    }
}

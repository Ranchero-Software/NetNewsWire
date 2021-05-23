//
//  SettingsAboutView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Combine

struct SettingsAboutView: View {

	@StateObject var viewModel = SettingsAboutModel()
	
    var body: some View {
		GeometryReader { geometry in
			List {
				Text("NetNewsWire").font(.largeTitle)
					AttributedStringView(string: self.viewModel.about, preferredMaxLayoutWidth: geometry.size.width - 20)
				Section(header: Text("CREDITS")) {
					AttributedStringView(string: self.viewModel.credits, preferredMaxLayoutWidth: geometry.size.width - 20)
				}
				Section(header: Text("THANKS")) {
					AttributedStringView(string: self.viewModel.thanks, preferredMaxLayoutWidth: geometry.size.width - 20)
				}
				Section(header: Text("DEDICATION"), footer: Text("Copyright © 2002-2021 Brent Simmons").font(.footnote)) {
					AttributedStringView(string: self.viewModel.dedication, preferredMaxLayoutWidth: geometry.size.width - 20)
				}
			}.listStyle(InsetGroupedListStyle())
		}
		.navigationTitle(Text("About"))
    }

}

struct SettingsAboutView_Previews: PreviewProvider {
    static var previews: some View {
		SettingsAboutView()
    }
}

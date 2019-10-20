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

	@ObservedObject var viewModel: ViewModel
	
    var body: some View {
		GeometryReader { geometry in
			List {
				Text("NetNewsWire").font(.largeTitle)
				AttributedStringView(string: self.viewModel.about, preferredMaxLayoutWidth: geometry.size.width - 20)
				Section(header: Text("CREDITS")) {
					AttributedStringView(string: self.viewModel.credits, preferredMaxLayoutWidth: geometry.size.width - 20)
				}
				Section(header: Text("ACKNOWLEDGEMENTS")) {
					AttributedStringView(string: self.viewModel.acknowledgements, preferredMaxLayoutWidth: geometry.size.width - 20)
				}
				Section(header: Text("THANKS")) {
					AttributedStringView(string: self.viewModel.thanks, preferredMaxLayoutWidth: geometry.size.width - 20)
				}
				Section(header: Text("DEDICATION"), footer: Text("Copyright © 2002-2019 Ranchero Software").font(.footnote)) {
					AttributedStringView(string: self.viewModel.dedication, preferredMaxLayoutWidth: geometry.size.width - 20)
				}
			}
		}
    }

	class ViewModel: ObservableObject {
		let objectWillChange = ObservableObjectPublisher()
		
		var about: NSAttributedString
		var credits: NSAttributedString
		var acknowledgements: NSAttributedString
		var thanks: NSAttributedString
		var dedication: NSAttributedString

		init() {
			about = ViewModel.loadResource("About")
			credits = ViewModel.loadResource("Credits")
			acknowledgements = ViewModel.loadResource("Acknowledgments")
			thanks = ViewModel.loadResource("Thanks")
			dedication = ViewModel.loadResource("Dedication")
		}
		
		private static func loadResource(_ resource: String) -> NSAttributedString {
			let url = Bundle.main.url(forResource: resource, withExtension: "rtf")!
			return try! NSAttributedString(url: url, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)

		}
		
	}
}

struct SettingsAboutView_Previews: PreviewProvider {
    static var previews: some View {
		SettingsAboutView(viewModel: SettingsAboutView.ViewModel())
    }
}

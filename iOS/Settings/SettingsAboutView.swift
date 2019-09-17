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
		Form {
			Text("NetNewsWire").font(.largeTitle)
			SettingsAttributedStringView(string: viewModel.about).frame(height: 54)
			Section(header: Text("CREDITS")) {
				SettingsAttributedStringView(string: viewModel.credits).frame(height: 135)
			}
			Section(header: Text("ACKNOWLEDGEMENTS")) {
				SettingsAttributedStringView(string: viewModel.acknowledgements).frame(height: 81)
			}
			Section(header: Text("THANKS")) {
				SettingsAttributedStringView(string: viewModel.thanks).frame(height: 189)
			}
			Section(header: Text("DEDICATION"), footer: Text("Copyright © 2002-2019 Ranchero Software").font(.footnote)) {
				SettingsAttributedStringView(string: viewModel.dedication).frame(height: 108)
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

//
//  SettingsRefreshSelectionView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SettingsRefreshSelectionView: View {

	@Environment(\.presentationMode) var presentation
	@Binding var selectedInterval: RefreshInterval
	
    var body: some View {
		Form {
			ForEach(RefreshInterval.allCases) { interval in
				Button(action: {
					self.selectedInterval = interval
					self.presentation.wrappedValue.dismiss()
				}) {
					HStack {
						Text(interval.description())
						Spacer()
						if interval == self.selectedInterval {
							Image(systemName: "checkmark")
						}
					}
				}.buttonStyle(VibrantButtonStyle(alignment: .leading))
			}
		}
	}
	
}

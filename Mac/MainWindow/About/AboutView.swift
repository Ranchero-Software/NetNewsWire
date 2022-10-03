//
//  AboutView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 03/10/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI

@available(macOS 12, *)
struct AboutView: View {
	
	enum AboutSelection: Int {
		case about = 0
		case credits = 1
	}
	
	@State private var selection: AboutSelection = .about
	
    var body: some View {
		VStack {
			if selection == .about {
				AboutNetNewsWireView()
			} else {
				CreditsNetNewsWireView()
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .AboutSelectionDidChange)) { newSelection in
			selection = AboutSelection(rawValue: newSelection.object as! Int)!
		}
		.frame(width: 400, height: 400)
    }
}


@available(macOS 12, *)
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}

//
//  AddAccountListView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 13/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct AddAccountListView: View {
    
	@Environment(\.dismiss) var dismiss
	
	var body: some View {
		NavigationView {
			AddAccountWrapper()
				.navigationTitle("Add Account")
				.navigationBarTitleDisplayMode(.inline)
				.edgesIgnoringSafeArea(.all)
		}
		.onReceive(NotificationCenter.default.publisher(for: .UserDidAddAccount)) { _ in
			dismiss()
		}
    }
}

struct AddAccountListView_Previews: PreviewProvider {
    static var previews: some View {
        AddAccountListView()
    }
}

//
//  PasswordField.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI

struct PasswordField: UIViewRepresentable {
    
	let password: Binding<String>
	
	func makeUIView(context: Context) -> ShowHidePasswordView {
		let showHideView = Bundle.main.loadNibNamed("ShowHidePasswordView", owner: Self.self, options: nil)?[0] as! ShowHidePasswordView
		showHideView.passwordTextField.bindingString = password
		return showHideView
	}

	func updateUIView(_ showHideView: ShowHidePasswordView, context: Context) {
		showHideView.passwordTextField.bindingString = password
	}

}

//
//  ShowHidePasswordView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import SwiftUI

class ShowHidePasswordView: UIView {

	@IBOutlet weak var passwordTextField: BindingTextField!
	@IBOutlet weak var showHideButton: UIButton!
	
	@IBAction func toggleShowHideButton(_ sender: Any) {
		if passwordTextField.isSecureTextEntry {
			passwordTextField.isSecureTextEntry = false
			showHideButton.setTitle(NSLocalizedString("Hide", comment: "Hide"), for: .normal)
		} else {
			passwordTextField.isSecureTextEntry = true
			showHideButton.setTitle(NSLocalizedString("Show", comment: "Show"), for: .normal)
		}
	}
	
}

class BindingTextField: UITextField, UITextFieldDelegate {
	
	var bindingString: Binding<String>? = nil
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		delegate = self
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		delegate = self
	}
	
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let currentValue = textField.text as NSString? {
            let proposedValue = currentValue.replacingCharacters(in: range, with: string)
			bindingString?.wrappedValue = proposedValue
        }
        return true
    }
	
}

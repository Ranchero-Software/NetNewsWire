//Copyright © 2019 Ranchero Software. All rights reserved.

import UIKit

extension UISplitViewController {
	
	func toggleMasterView() {
		let barButtonItem = self.displayModeButtonItem
		if let action = barButtonItem.action {
			UIApplication.shared.sendAction(action, to: barButtonItem.target, from: nil, for: nil)
		}
	}
	
}

//
//  UIStoryboard-Extensions.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

#if os(iOS)

import UIKit

extension UIStoryboard {
	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 400.0)

	public static var main: UIStoryboard {
		UIStoryboard(name: "Main", bundle: nil)
	}

	public static var add: UIStoryboard {
		UIStoryboard(name: "Add", bundle: nil)
	}

	public static var settings: UIStoryboard {
		UIStoryboard(name: "Settings", bundle: nil)
	}

	public static var inspector: UIStoryboard {
		UIStoryboard(name: "Inspector", bundle: nil)
	}

	public static var account: UIStoryboard {
		UIStoryboard(name: "Account", bundle: nil)
	}

	public func instantiateController<T>(ofType type: T.Type = T.self) -> T where T: UIViewController {
		let storyboardId = String(describing: type)
		guard let viewController = instantiateViewController(withIdentifier: storyboardId) as? T else {
			print("Unable to load view with Scene Identifier: \(storyboardId)")
			fatalError()
		}

		return viewController
	}
}

#endif

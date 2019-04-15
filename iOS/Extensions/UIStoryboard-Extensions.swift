//
//  UIStoryboard+.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

extension UIStoryboard {
	
	static var main: UIStoryboard {
		return UIStoryboard(name: "Main", bundle: nil)
	}
	
	func instantiateController<T>(ofType type: T.Type = T.self) -> T where T: UIViewController {
		
		let storyboardId = String(describing: type)
		guard let viewController = instantiateViewController(withIdentifier: storyboardId) as? T else {
			print("Unable to load view with Scene Identifier: \(storyboardId)")
			fatalError()
		}
		
		return viewController
		
	}
	
}

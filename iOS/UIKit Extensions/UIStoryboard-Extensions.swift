//
//  UIStoryboard-Extensions.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

extension UIStoryboard {
	
	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 400.0)
	
	static var main: UIStoryboard {
		return UIStoryboard(name: "Main", bundle: nil)
	}
	
	static var add: UIStoryboard {
		return UIStoryboard(name: "Add", bundle: nil)
	}
	
	static var redditAdd: UIStoryboard {
		return UIStoryboard(name: "RedditAdd", bundle: nil)
	}
	
	static var twitterAdd: UIStoryboard {
		return UIStoryboard(name: "TwitterAdd", bundle: nil)
	}
	
	static var settings: UIStoryboard {
		return UIStoryboard(name: "Settings", bundle: nil)
	}
	
	static var inspector: UIStoryboard {
		return UIStoryboard(name: "Inspector", bundle: nil)
	}
	
	static var account: UIStoryboard {
		return UIStoryboard(name: "Account", bundle: nil)
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

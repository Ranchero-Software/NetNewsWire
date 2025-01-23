//
//  UIViewController-Extensions.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/15/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//
#if os(iOS)
import UIKit
import SwiftUI

extension UIViewController {

	// MARK: Autolayout

	public func addChildAndPinView(_ controller: UIViewController) {
		view.addChildAndPin(controller.view)
		addChild(controller)
	}

	public func replaceChildAndPinView(_ controller: UIViewController) {
		for subview in view.subviews {
			subview.removeFromSuperview()
		}
		for child in children {
			child.removeFromParent()
		}
		addChildAndPinView(controller)
	}

	// MARK: Error Handling

	public func presentError(title: String, message: String, dismiss: (() -> Void)? = nil) {
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let dismissTitle = NSLocalizedString("OK", comment: "OK")
		let dismissAction = UIAlertAction(title: dismissTitle, style: .default) { _ in
			dismiss?()
		}
		alertController.addAction(dismissAction)
		self.present(alertController, animated: true, completion: nil)
	}

}

// MARK: SwiftUI

public struct ViewControllerHolder {
	public weak var value: UIViewController?
}

public struct ViewControllerKey: EnvironmentKey {
	public static var defaultValue: ViewControllerHolder { return ViewControllerHolder(value: nil ) }
}

extension EnvironmentValues {
	public var viewController: UIViewController? {
		get { return self[ViewControllerKey.self].value }
		set { self[ViewControllerKey.self].value = newValue }
	}
}

extension UIViewController {
	public func present<Content: View>(style: UIModalPresentationStyle = .automatic, @ViewBuilder builder: () -> Content) {
		let controller = UIHostingController(rootView: AnyView(EmptyView()))
		controller.modalPresentationStyle = style
		controller.rootView = AnyView(
			builder().environment(\.viewController, controller)
		)
		self.present(controller, animated: true, completion: nil)
	}
}
#endif

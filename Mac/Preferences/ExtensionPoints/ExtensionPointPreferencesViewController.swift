//
//  ExtensionsPreferencesViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import SwiftUI
import AuthenticationServices
import OAuthSwift
import Secrets

protocol ExtensionPointPreferencesEnabler: AnyObject {
	func enable(_ extensionPointType: ExtensionPoint.Type)
}

final class ExtensionPointPreferencesViewController: NSViewController {

	@IBOutlet weak var tableView: NSTableView!
	@IBOutlet weak var detailView: NSView!
	@IBOutlet weak var deleteButton: NSButton!
	
	private var activeExtensionPoints = [ExtensionPoint]()
	private var callbackURL: URL? = nil
	private var oauth: OAuthSwift?

	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.delegate = self
		tableView.dataSource = self

		NotificationCenter.default.addObserver(self, selector: #selector(activeExtensionPointsDidChange(_:)), name: .ActiveExtensionPointsDidChange, object: nil)

		// Fix tableView frame — for some reason IB wants it 1pt wider than the clip view. This leads to unwanted horizontal scrolling.
		var rTable = tableView.frame
		rTable.size.width = tableView.superview!.frame.size.width
		tableView.frame = rTable
		
		showDefaultView()
		
	}
	
	@IBAction func enableExtensionPoints(_ sender: Any) {
		let controller = NSHostingController(rootView: EnableExtensionPointView(enabler: self, selectedType: nil))
		controller.rootView.parent = controller
		presentAsSheet(controller)
	}
	
	func enableExtensionPointFromSelection(_ selection: ExtensionPoint.Type) {
		let controller = NSHostingController(rootView: EnableExtensionPointView(enabler: self, selectedType: selection))
		controller.rootView.parent = controller
		presentAsSheet(controller)
	}
	
	@IBAction func disableExtensionPoint(_ sender: Any) {
		guard tableView.selectedRow != -1 else {
			return
		}
		
		let extensionPoint = activeExtensionPoints[tableView.selectedRow]
		
		let alert = NSAlert()
		alert.alertStyle = .warning
		let prompt = NSLocalizedString("Deactivate", comment: "Deactivate")
		alert.messageText = "\(prompt) “\(extensionPoint.title)”?"
		let extensionPointTypeTitle = extensionPoint.extensionPointID.extensionPointType.title
		alert.informativeText = NSLocalizedString("Are you sure you want to deactivate the \(extensionPointTypeTitle) extension “\(extensionPoint.title)”?", comment: "Deactivate text")
		
		alert.addButton(withTitle: NSLocalizedString("Deactivate", comment: "Deactivate Extension"))
		alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel Deactivate Extension"))
			
		alert.beginSheetModal(for: view.window!) { [weak self] result in
			if result == NSApplication.ModalResponse.alertFirstButtonReturn {
				ExtensionPointManager.shared.deactivateExtensionPoint(extensionPoint.extensionPointID)
				self?.hideController()
			}
		}

	}
}

// MARK: - NSTableViewDataSource

extension ExtensionPointPreferencesViewController: NSTableViewDataSource {

	func numberOfRows(in tableView: NSTableView) -> Int {
		return activeExtensionPoints.count
	}

	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		return activeExtensionPoints[row]
	}
}

// MARK: - NSTableViewDelegate

extension ExtensionPointPreferencesViewController: NSTableViewDelegate {

	private static let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "AccountCell")

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell"), owner: nil) as? NSTableCellView {
			let extensionPoint = activeExtensionPoints[row]
			cell.textField?.stringValue = extensionPoint.title
			cell.imageView?.image = extensionPoint.image
			return cell
		}
		return nil
	}

	func tableViewSelectionDidChange(_ notification: Notification) {
		
		let selectedRow = tableView.selectedRow
		if tableView.selectedRow == -1 {
			deleteButton.isEnabled = false
			hideController()
			return
		} else {
			deleteButton.isEnabled = true
		}

		let extensionPoint = activeExtensionPoints[selectedRow]
		let controller = ExtensionPointDetailViewController(extensionPoint: extensionPoint)
		showController(controller)
		
	}
	
}

// MARK: ExtensionPointPreferencesViewController

extension ExtensionPointPreferencesViewController: ExtensionPointPreferencesEnabler {
	
	func enable(_ extensionPointType: ExtensionPoint.Type) {
		if let oauth1 = extensionPointType as? OAuth1SwiftProvider.Type {
			enableOauth1(oauth1, extensionPointType: extensionPointType)
		} else if let oauth2 = extensionPointType as? OAuth2SwiftProvider.Type {
			enableOauth2(oauth2, extensionPointType: extensionPointType)
		} else {
			ExtensionPointManager.shared.activateExtensionPoint(extensionPointType) { result in
				if case .failure(let error) = result {
					self.presentError(error)
				}
			}
		}
	}
	
}

extension ExtensionPointPreferencesViewController: OAuthSwiftURLHandlerType {
	
	public func handle(_ url: URL) {
		let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURL!.scheme, completionHandler: { (url, error) in
			if let callbackedURL = url {
				OAuth1Swift.handle(url: callbackedURL)
			}
			
			guard let error = error else { return }

			self.oauth?.cancel()
			self.oauth = nil

			if case ASWebAuthenticationSessionError.canceledLogin = error {
				print("Login cancelled.")
			} else {
				NSApplication.shared.presentError(error)
			}
		})
		
		session.presentationContextProvider = self
		if !session.start() {
			print("Session failed to start!!!")
		}
		
	}
}

extension ExtensionPointPreferencesViewController: ASWebAuthenticationPresentationContextProviding {
	
	public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		return view.window!
	}
	
}

// MARK: - Private

private extension ExtensionPointPreferencesViewController {
	
	@objc func activeExtensionPointsDidChange(_ note: Notification) {
		showDefaultView()
	}
	
	func showDefaultView() {
		activeExtensionPoints = Array(ExtensionPointManager.shared.activeExtensionPoints.values).sorted(by: { $0.title < $1.title })
		tableView.reloadData()
		
		if tableView.selectedRow == -1 {
			var helpText = ""
			if ExtensionPointManager.shared.availableExtensionPointTypes.count == 0 {
				helpText = NSLocalizedString("You've added all available extensions.", comment: "Extension Explainer")
			}
			else if activeExtensionPoints.count == 0 {
				helpText = NSLocalizedString("Add an extension by clicking the + button.", comment: "Extension Explainer")
			} else {
				helpText = NSLocalizedString("Select an extension or add a new extension by clicking the + button.", comment: "Extension Explainer")
			}
			
			if let controller = children.first {
				children.removeAll()
				controller.view.removeFromSuperview()
			}
			
			let textHostingController = NSHostingController(rootView: EnableExtensionPointHelpView(helpText: helpText, preferencesController: self))
			addChild(textHostingController)
			textHostingController.view.translatesAutoresizingMaskIntoConstraints = false
			detailView.addSubview(textHostingController.view)
			detailView.addConstraints([
										NSLayoutConstraint(item: textHostingController.view, attribute: .top, relatedBy: .equal, toItem: detailView, attribute: .top, multiplier: 1, constant: 1),
										NSLayoutConstraint(item: textHostingController.view, attribute: .bottom, relatedBy: .equal, toItem: detailView, attribute: .bottom, multiplier: 1, constant: -deleteButton.frame.height),
				NSLayoutConstraint(item: textHostingController.view, attribute: .width, relatedBy: .equal, toItem: detailView, attribute: .width, multiplier: 1, constant: 1)
			])
		}
	}
	
	func showController(_ controller: NSViewController) {
		hideController()
		
		addChild(controller)
		controller.view.translatesAutoresizingMaskIntoConstraints = false
		detailView.addSubview(controller.view)
		detailView.addFullSizeConstraints(forSubview: controller.view)
	}

	func hideController() {
		if let controller = children.first {
			children.removeAll()
			controller.view.removeFromSuperview()
		}
		
		if tableView.selectedRow == -1 {
			var helpText = ""
			if ExtensionPointManager.shared.availableExtensionPointTypes.count == 0 {
				helpText = NSLocalizedString("You've added all available extensions.", comment: "Extension Explainer")
			}
			else if activeExtensionPoints.count == 0 {
				helpText = NSLocalizedString("Add an extension by clicking the + button.", comment: "Extension Explainer")
			} else {
				helpText = NSLocalizedString("Select an extension or add a new extension by clicking the + button.", comment: "Extension Explainer")
			}
			
			let textHostingController = NSHostingController(rootView: EnableExtensionPointHelpView(helpText: helpText, preferencesController: self))
			addChild(textHostingController)
			textHostingController.view.translatesAutoresizingMaskIntoConstraints = false
			detailView.addSubview(textHostingController.view)
			detailView.addConstraints([
										NSLayoutConstraint(item: textHostingController.view, attribute: .top, relatedBy: .equal, toItem: detailView, attribute: .top, multiplier: 1, constant: 1),
										NSLayoutConstraint(item: textHostingController.view, attribute: .bottom, relatedBy: .equal, toItem: detailView, attribute: .bottom, multiplier: 1, constant: -deleteButton.frame.height),
				NSLayoutConstraint(item: textHostingController.view, attribute: .width, relatedBy: .equal, toItem: detailView, attribute: .width, multiplier: 1, constant: 1)
			])
		}
	}

	func enableOauth1(_ provider: OAuth1SwiftProvider.Type, extensionPointType: ExtensionPoint.Type) {
		callbackURL = provider.callbackURL

		let oauth1 = provider.oauth1Swift
		self.oauth = oauth1
		oauth1.authorizeURLHandler = self
		
		oauth1.authorize(withCallbackURL: callbackURL!) { [weak self] result in
			guard let self = self else { return }

			switch result {
			case .success(let tokenSuccess):
				ExtensionPointManager.shared.activateExtensionPoint(extensionPointType, tokenSuccess: tokenSuccess) { result in
					if case .failure(let error) = result {
						self.presentError(error)
					}
				}
			case .failure(let oauthSwiftError):
				self.presentError(oauthSwiftError)
			}
			
			self.oauth?.cancel()
			self.oauth = nil
		}
		
	}
	
	func enableOauth2(_ provider: OAuth2SwiftProvider.Type, extensionPointType: ExtensionPoint.Type) {
		callbackURL = provider.callbackURL

		let oauth2 = provider.oauth2Swift
		self.oauth = oauth2
		oauth2.authorizeURLHandler = self
		
		let oauth2Vars = provider.oauth2Vars
		
		oauth2.authorize(withCallbackURL: callbackURL!, scope: oauth2Vars.scope, state: oauth2Vars.state, parameters: oauth2Vars.params) { [weak self] result in
			guard let self = self else { return }

			switch result {
			case .success(let tokenSuccess):
				ExtensionPointManager.shared.activateExtensionPoint(extensionPointType, tokenSuccess: tokenSuccess) { result in
					if case .failure(let error) = result {
						self.presentError(error)
					}
				}
			case .failure(let oauthSwiftError):
				self.presentError(oauthSwiftError)
			}
			
			self.oauth?.cancel()
			self.oauth = nil
		}
		
	}
	
}



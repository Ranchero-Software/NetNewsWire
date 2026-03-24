//
//  CloudKitStatsViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/20/26.
//

import AppKit
import Account
import RSWeb

final class CloudKitStatsViewController: NSViewController {

	private let model = CloudKitStatsViewModel()
	private let toolbarView = CloudKitStatsToolbarView()
	private let contentAreaView = NSView()
	private var currentChild: NSViewController?
	private var hasAppeared = false

	override func loadView() {
		let containerView = NSView(frame: .zero)

		contentAreaView.translatesAutoresizingMaskIntoConstraints = false

		containerView.addSubview(contentAreaView)
		containerView.addSubview(toolbarView)

		NSLayoutConstraint.activate([
			contentAreaView.topAnchor.constraint(equalTo: containerView.topAnchor),
			contentAreaView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: CloudKitStatsLayout.horizontalPadding),
			contentAreaView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -CloudKitStatsLayout.horizontalPadding),
			contentAreaView.bottomAnchor.constraint(equalTo: toolbarView.topAnchor),

			toolbarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			toolbarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
			toolbarView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
		])

		self.view = containerView
	}

	override func viewDidAppear() {
		super.viewDidAppear()

		if !hasAppeared {
			hasAppeared = true
			model.onChange = { [weak self] in
				self?.updateUI()
			}
			switchToScan()
			model.fetch()
		}
		updateUI()
	}
}

// MARK: - Actions

extension CloudKitStatsViewController {

	@objc func refreshScan(_ sender: Any?) {
		model.fetch()
	}

	@objc func cancelScan(_ sender: Any?) {
		model.cancelFetch()
	}

	@objc func cancelCleanUp(_ sender: Any?) {
		model.cancelCleanUp()
	}

	@objc func returnToPreviousScanResults(_ sender: Any?) {
		model.cleanUpStatus = .idle
		updateUI()
	}

	@objc func showHelp(_ sender: Any?) {
		if let url = URL(string: "https://netnewswire.com/help/icloud.html") {
			MacWebBrowser.openURL(url)
		}
	}

	@objc func shareStats(_ sender: Any?) {
		guard let button = sender as? NSButton else {
			return
		}
		let text = model.cleanUpStatus.isActive ? model.cleanUpStatsText : model.statsText
		let picker = NSSharingServicePicker(items: [text])
		picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
	}

	@objc func cleanUp(_ sender: Any?) {
		let plan = model.cleanUpPlan
		guard !plan.isEmpty else {
			return
		}

		let alert = NSAlert()
		alert.alertStyle = .warning
		alert.messageText = NSLocalizedString("Clean Up iCloud Records", comment: "Clean up alert title")
		alert.informativeText = cleanUpConfirmationText(plan)
		alert.addButton(withTitle: NSLocalizedString("Clean Up", comment: "Clean up alert button"))
		alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button"))

		guard let window = view.window else {
			return
		}

		alert.beginSheetModal(for: window) { [weak self] response in
			guard response == .alertFirstButtonReturn else {
				return
			}
			self?.model.cleanUp()
		}
	}
}

// MARK: - Private

private extension CloudKitStatsViewController {

	// MARK: - Child View Controller Management

	func switchToCleanUp() {
		let incoming = CloudKitStatsCleanUpViewController(model: model)
		switchToChild(incoming)
		incoming.updateUI()
	}

	func switchToScan() {
		let incoming = CloudKitStatsScanViewController(model: model)
		switchToChild(incoming)
		incoming.updateUI()
	}

	func switchToChild(_ incoming: NSViewController) {
		addChild(incoming)
		incoming.view.translatesAutoresizingMaskIntoConstraints = false

		let constraints = [
			incoming.view.topAnchor.constraint(equalTo: contentAreaView.topAnchor),
			incoming.view.leadingAnchor.constraint(equalTo: contentAreaView.leadingAnchor),
			incoming.view.trailingAnchor.constraint(equalTo: contentAreaView.trailingAnchor),
			incoming.view.bottomAnchor.constraint(equalTo: contentAreaView.bottomAnchor)
		]

		if let outgoing = currentChild {
			NSLayoutConstraint.activate(constraints)
			NSAnimationContext.runAnimationGroup { context in
				context.duration = CloudKitStatsLayout.animationDuration
				context.allowsImplicitAnimation = true
				transition(from: outgoing, to: incoming, options: .crossfade) {
					Task { @MainActor in
						outgoing.removeFromParent()
					}
				}
			}
		} else {
			contentAreaView.addSubview(incoming.view)
			NSLayoutConstraint.activate(constraints)
		}

		currentChild = incoming
	}

	// MARK: - UI Update

	func updateUI() {
		let shouldShowCleanUp = model.cleanUpStatus.isActive
		let isShowingCleanUp = currentChild is CloudKitStatsCleanUpViewController

		if shouldShowCleanUp != isShowingCleanUp {
			if shouldShowCleanUp {
				switchToCleanUp()
			} else {
				switchToScan()
			}
		} else if let child = currentChild as? CloudKitStatsScanViewController {
			child.updateUI()
		} else if let child = currentChild as? CloudKitStatsCleanUpViewController {
			child.updateUI()
		}
		updateToolbar()
	}

	func updateToolbar() {
		let isCleaning = model.cleanUpStatus.isCleaning
		let isCleanUpDone = model.cleanUpStatus.isCompleted || model.cleanUpStatus.isCanceled || model.cleanUpStatus.cleanUpError != nil

		if isCleaning {
			toolbarView.cleanUpButton.isEnabled = false
			toolbarView.shareButton.isEnabled = true
		} else if isCleanUpDone {
			toolbarView.cleanUpButton.isEnabled = true
			toolbarView.shareButton.isEnabled = true
		} else {
			let enableShare = model.fetchStatus.isCompleted || model.fetchStatus.fetchError != nil
			toolbarView.shareButton.isEnabled = enableShare
			toolbarView.cleanUpButton.isEnabled = model.canCleanUp
		}
	}

	func cleanUpConfirmationText(_ plan: CloudKitCleanUpPlan) -> String {
		var lines = [String]()
		if plan.staleStatusCount > 0 {
			lines.append(CloudKitStatsLayout.formattedCount(plan.staleStatusCount, singular: NSLocalizedString("stale status record", comment: "Singular label for stale status records"), plural: NSLocalizedString("stale status records", comment: "Plural label for stale status records")))
		}
		if plan.readContentCount > 0 {
			lines.append(CloudKitStatsLayout.formattedCount(plan.readContentCount, singular: NSLocalizedString("read content record", comment: "Singular label for read content records"), plural: NSLocalizedString("read content records", comment: "Plural label for read content records")))
		}
		if plan.unreadContentCount > 0 {
			lines.append(CloudKitStatsLayout.formattedCount(plan.unreadContentCount, singular: NSLocalizedString("unread content record", comment: "Singular label for unread content records"), plural: NSLocalizedString("unread content records", comment: "Plural label for unread content records")))
		}
		if plan.orphanedContentCount > 0 {
			lines.append(CloudKitStatsLayout.formattedCount(plan.orphanedContentCount, singular: NSLocalizedString("orphaned content record", comment: "Singular label for orphaned content records"), plural: NSLocalizedString("orphaned content records", comment: "Plural label for orphaned content records")))
		}
		let listText = lines.map { "• " + $0 }.joined(separator: "\n")
		return NSLocalizedString("This will delete:", comment: "Clean up confirmation prefix") + "\n" + listText + "\n\n" + NSLocalizedString("This may take many minutes.", comment: "Clean up confirmation suffix")
	}
}

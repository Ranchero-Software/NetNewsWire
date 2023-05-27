//
//  ArticleThemeImporter.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/18/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

struct ArticleThemeImporter: Logging {
	
	static func importTheme(controller: UIViewController, filename: String) {
		let theme: ArticleTheme
		do {
			theme = try ArticleTheme(path: filename, isAppTheme: false)
		} catch {
			controller.presentError(error)
			return
		}
		
		let localizedTitleText = NSLocalizedString("alert.title.install-theme.%@.%@", comment: "Variable ordering is theme name; author name. In English, the alert title is: Install theme “%@” by %@?")
		let title = NSString.localizedStringWithFormat(localizedTitleText as NSString, theme.name, theme.creatorName) as String

		let localizedMessageText = NSLocalizedString("alert.message.author-website.%@", comment: "The variable is the author's home page. In English, the alert message is: Author‘s website:\n%@")
		let message = NSString.localizedStringWithFormat(localizedMessageText as NSString, theme.creatorHomePage) as String

		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("button.title.cancel", comment: "Cancel")
		alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
		
		if let url = URL(string: theme.creatorHomePage) {
			let visitSiteTitle = NSLocalizedString("button.title.show-website", comment: "Show Website")
			let visitSiteAction = UIAlertAction(title: visitSiteTitle, style: .default) { action in
				UIApplication.shared.open(url)
				Self.importTheme(controller: controller, filename: filename)
			}
			alertController.addAction(visitSiteAction)
		}

		func importTheme() {
			do {
				try ArticleThemesManager.shared.importTheme(filename: filename)
				confirmImportSuccess(controller: controller, themeName: theme.name)
			} catch {
				controller.presentError(error)
				ArticleThemeImporter.logger.error("Error importing theme: \(error.localizedDescription, privacy: .public)")
			}
		}

		let installThemeTitle = NSLocalizedString("alert.title.install-theme", comment: "Install Theme")
		let installThemeAction = UIAlertAction(title: installThemeTitle, style: .default) { action in

			if ArticleThemesManager.shared.themeExists(filename: filename) {
				let title = NSLocalizedString("alert.title.duplicate-theme", comment: "Duplicate Theme")
				let localizedMessageText = NSLocalizedString("alert.message.duplicate-theme.%@", comment: "This message details that this theme is a duplicate and gives the user the option to overwrite the existing theme. In English, the message is: The theme “%@” already exists. Overwrite it?")
				let message = NSString.localizedStringWithFormat(localizedMessageText as NSString, theme.name) as String

				let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

				let cancelTitle = NSLocalizedString("button.title.cancel", comment: "Cancel")
				alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

				let overwriteAction = UIAlertAction(title: NSLocalizedString("button.title.overwrite", comment: "Overwrite"), style: .default) { action in
					importTheme()
				}
				alertController.addAction(overwriteAction)
				alertController.preferredAction = overwriteAction

				controller.present(alertController, animated: true)
			} else {
				importTheme()
			}
			
		}
		
		alertController.addAction(installThemeAction)
		alertController.preferredAction = installThemeAction

		controller.present(alertController, animated: true)

	}
	
}

private extension ArticleThemeImporter {
	
	static func confirmImportSuccess(controller: UIViewController, themeName: String) {
		let title = NSLocalizedString("alert.title.theme-installed", comment: "Theme installed")
		
		let localizedMessageText = NSLocalizedString("alert.message.theme-installed.%@", comment: "This alert message provides confirmation that the theme has been installed. In English, the message is: The theme “%@” has been installed.")
		let message = NSString.localizedStringWithFormat(localizedMessageText as NSString, themeName) as String

		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		
		let doneTitle = NSLocalizedString("button.title.done", comment: "Done")
		alertController.addAction(UIAlertAction(title: doneTitle, style: .default))
		
		controller.present(alertController, animated: true)
	}
	
}

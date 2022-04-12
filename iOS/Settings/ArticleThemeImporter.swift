//
//  ArticleThemeImporter.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/18/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import UIKit

struct ArticleThemeImporter {
	
	static func importTheme(controller: UIViewController, filename: String) throws {
		let theme = try ArticleTheme(path: filename, isAppTheme: false)
		
		let localizedTitleText = NSLocalizedString("Install theme “%@” by %@?", comment: "Theme message text")
		let title = NSString.localizedStringWithFormat(localizedTitleText as NSString, theme.name, theme.creatorName) as String

		let localizedMessageText = NSLocalizedString("Author‘s website:\n%@", comment: "Authors website")
		let message = NSString.localizedStringWithFormat(localizedMessageText as NSString, theme.creatorHomePage) as String

		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
		
		if let url = URL(string: theme.creatorHomePage) {
			let visitSiteTitle = NSLocalizedString("Show Website", comment: "Show Website")
			let visitSiteAction = UIAlertAction(title: visitSiteTitle, style: .default) { action in
				UIApplication.shared.open(url)
				try? Self.importTheme(controller: controller, filename: filename)
			}
			alertController.addAction(visitSiteAction)
		}

		func importTheme() {
			do {
				try ArticleThemesManager.shared.importTheme(filename: filename)
				confirmImportSuccess(controller: controller, themeName: theme.name)
			} catch {
				controller.presentError(error)
			}
		}

		let installThemeTitle = NSLocalizedString("Install Theme", comment: "Install Theme")
		let installThemeAction = UIAlertAction(title: installThemeTitle, style: .default) { action in

			if ArticleThemesManager.shared.themeExists(filename: filename) {
				let title = NSLocalizedString("Duplicate Theme", comment: "Duplicate Theme")
				let localizedMessageText = NSLocalizedString("The theme “%@” already exists. Overwrite it?", comment: "Overwrite theme")
				let message = NSString.localizedStringWithFormat(localizedMessageText as NSString, theme.name) as String

				let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

				let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
				alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

				let overwriteAction = UIAlertAction(title: NSLocalizedString("Overwrite", comment: "Overwrite"), style: .default) { action in
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
		let title = NSLocalizedString("Theme installed", comment: "Theme installed")
		
		let localizedMessageText = NSLocalizedString("The theme “%@” has been installed.", comment: "Theme installed")
		let message = NSString.localizedStringWithFormat(localizedMessageText as NSString, themeName) as String

		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		
		let doneTitle = NSLocalizedString("Done", comment: "Done")
		alertController.addAction(UIAlertAction(title: doneTitle, style: .default))
		
		controller.present(alertController, animated: true)
	}
	
}

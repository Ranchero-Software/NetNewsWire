//
//  AppDelegate+Shared.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/19/26.
//

import Foundation
import Account
import ActivityLog
import ErrorLog
import HTMLMetadata
import Images
import RSCore

extension AppDelegate {

	/// Vacuum every database the app owns — the app-level error-log, HTML-metadata,
	/// and image-metadata databases, plus each account's databases.
	func vacuumAllDatabases() async {
		await vacuumAndLog(databasePath: AccountManager.shared.errorLogDatabase.databasePath) {
			await AccountManager.shared.errorLogDatabase.vacuum()
		}
		await vacuumAndLog(databasePath: HTMLMetadataDatabase.shared.databasePath) {
			await HTMLMetadataDatabase.shared.vacuum()
		}
		await vacuumAndLog(databasePath: ImageMetadataDatabase.shared.databasePath) {
			await ImageMetadataDatabase.shared.vacuum()
		}
		await AccountManager.shared.vacuumAccountDatabases()
	}

	private func vacuumAndLog(databasePath: String, _ work: () async -> Void) async {
		await ActivityLog.shared.logActivity(owner: .app, kind: .vacuumDatabase, detail: AppConfig.relativeDataPath(databasePath)) {
			await work()
		}
	}
}

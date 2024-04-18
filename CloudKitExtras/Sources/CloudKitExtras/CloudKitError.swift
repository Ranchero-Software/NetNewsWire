//
//  CloudKitError.swift
//  RSCore
//
//  Created by Maurice Parker on 3/26/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//
// Derived from https://github.com/caiyue1993/IceCream

import Foundation
import CloudKit

public final class CloudKitError: LocalizedError {

	public let error: Error
	
	public init(_ error: Error) {
		self.error = error
	}
	
	public var errorDescription: String? {
		guard let ckError = error as? CKError else {
			return error.localizedDescription
		}
		
		switch ckError.code {
		case .alreadyShared:
			return NSLocalizedString("Already Shared: a record or share cannot be saved because doing so would cause the same hierarchy of records to exist in multiple shares.", comment: "Known iCloud Error")
		case .assetFileModified:
			return NSLocalizedString("Asset File Modified: the content of the specified asset file was modified while being saved.", comment: "Known iCloud Error")
		case .assetFileNotFound:
			return NSLocalizedString("Asset File Not Found: the specified asset file is not found.", comment: "Known iCloud Error")
		case .badContainer:
			return NSLocalizedString("Bad Container: the specified container is unknown or unauthorized.", comment: "Known iCloud Error")
		case .badDatabase:
			return NSLocalizedString("Bad Database: the operation could not be completed on the given database.", comment: "Known iCloud Error")
		case .batchRequestFailed:
			return NSLocalizedString("Batch Request Failed: the entire batch was rejected.", comment: "Known iCloud Error")
		case .changeTokenExpired:
			return NSLocalizedString("Change Token Expired: the previous server change token is too old.", comment: "Known iCloud Error")
		case .constraintViolation:
			return NSLocalizedString("Constraint Violation: the server rejected the request because of a conflict with a unique field.", comment: "Known iCloud Error")
		case .incompatibleVersion:
			return NSLocalizedString("Incompatible Version: your app version is older than the oldest version allowed.", comment: "Known iCloud Error")
		case .internalError:
			return NSLocalizedString("Internal Error: a nonrecoverable error was encountered by CloudKit.", comment: "Known iCloud Error")
		case .invalidArguments:
			return NSLocalizedString("Invalid Arguments: the specified request contains bad information.", comment: "Known iCloud Error")
		case .limitExceeded:
			return NSLocalizedString("Limit Exceeded: the request to the server is too large.", comment: "Known iCloud Error")
		case .managedAccountRestricted:
			return NSLocalizedString("Managed Account Restricted: the request was rejected due to a managed-account restriction.", comment: "Known iCloud Error")
		case .missingEntitlement:
			return NSLocalizedString("Missing Entitlement: the app is missing a required entitlement.", comment: "Known iCloud Error")
		case .networkUnavailable:
			return NSLocalizedString("Network Unavailable: the internet connection appears to be offline.", comment: "Known iCloud Error")
		case .networkFailure:
			return NSLocalizedString("Network Failure: the internet connection appears to be offline.", comment: "Known iCloud Error")
		case .notAuthenticated:
			return NSLocalizedString("Not Authenticated: to use the iCloud account, you must enable iCloud Drive. Go to device Settings, sign in to iCloud, then in the app settings, be sure the iCloud Drive feature is enabled.", comment: "Known iCloud Error")
		case .operationCancelled:
			return NSLocalizedString("Operation Cancelled: the operation was explicitly canceled.", comment: "Known iCloud Error")
		case .partialFailure:
			return NSLocalizedString("Partial Failure: some items failed, but the operation succeeded overall.", comment: "Known iCloud Error")
		case .participantMayNeedVerification:
			return NSLocalizedString("Participant May Need Verification: you are not a member of the share.", comment: "Known iCloud Error")
		case .permissionFailure:
			return NSLocalizedString("Permission Failure: to use this app, you must enable iCloud Drive. Go to device Settings, sign in to iCloud, then in the app settings, be sure the iCloud Drive feature is enabled.", comment: "Known iCloud Error")
		case .quotaExceeded:
			return NSLocalizedString("Quota Exceeded: saving would exceed your current iCloud storage quota.", comment: "Known iCloud Error")
		case .referenceViolation:
			return NSLocalizedString("Reference Violation: the target of a record's parent or share reference was not found.", comment: "Known iCloud Error")
		case .requestRateLimited:
			return NSLocalizedString("Request Rate Limited: transfers to and from the server are being rate limited at this time.", comment: "Known iCloud Error")
		case .serverRecordChanged:
			return NSLocalizedString("Server Record Changed: the record was rejected because the version on the server is different.", comment: "Known iCloud Error")
		case .serverRejectedRequest:
			return NSLocalizedString("Server Rejected Request", comment: "Known iCloud Error")
		case .serverResponseLost:
			return NSLocalizedString("Server Response Lost", comment: "Known iCloud Error")
		case .serviceUnavailable:
			return NSLocalizedString("Service Unavailable: Please try again.", comment: "Known iCloud Error")
		case .tooManyParticipants:
			return NSLocalizedString("Too Many Participants: a share cannot be saved because too many participants are attached to the share.", comment: "Known iCloud Error")
		case .unknownItem:
			return NSLocalizedString("Unknown Item:  the specified record does not exist.", comment: "Known iCloud Error")
		case .userDeletedZone:
			return NSLocalizedString("User Deleted Zone: the user has deleted this zone from the settings UI.", comment: "Known iCloud Error")
		case .zoneBusy:
			return NSLocalizedString("Zone Busy: the server is too busy to handle the zone operation.", comment: "Known iCloud Error")
		case .zoneNotFound:
			return NSLocalizedString("Zone Not Found: the specified record zone does not exist on the server.", comment: "Known iCloud Error")
		default:
			return NSLocalizedString("Unhandled Error.", comment: "Unknown iCloud Error")
		}
	}
}

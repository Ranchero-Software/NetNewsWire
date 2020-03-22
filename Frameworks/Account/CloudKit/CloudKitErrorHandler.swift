//
//  CloudKitErrorHandler.swift
//  Account
//
//  Created by @randycarney on 12/12/17.
//  Derived from https://github.com/caiyue1993/IceCream
//

import Foundation
import CloudKit

/// This struct helps you handle all the CKErrors and has been updated to the current Apple documentation(12/15/2017):
/// https://developer.apple.com/documentation/cloudkit/ckerror.code

struct CloudKitErrorHandler {
	
	static let shared = CloudKitErrorHandler()
	
	/// We could classify all the results that CKOperation returns into the following five CKOperationResultTypes
	enum CloudKitOperationResultType {
		case success
		case retry(afterSeconds: Double, message: String)
		case chunk
		case recoverableError(reason: CloudKitOperationFailReason, message: String)
		case fail(reason: CloudKitOperationFailReason, message: String)
	}
	
	/// The reason of CloudKit failure could be classified into following 8 cases
	enum CloudKitOperationFailReason {
		case changeTokenExpired
		case network
		case quotaExceeded
		case partialFailure
		case serverRecordChanged
		case shareRelated
		case unhandledErrorCode
		case unknown
	}
	
	func resultType(with error: Error?) -> CloudKitOperationResultType {
		guard error != nil else { return .success }
		
		guard let e = error as? CKError else {
			return .fail(reason: .unknown, message: "The error returned is not a CKError")
		}
		
		let message = returnErrorMessage(for: e.code)
		
		switch e.code {
			
		// SHOULD RETRY
		case .serviceUnavailable,
			 .requestRateLimited,
			 .zoneBusy:
			
			// If there is a retry delay specified in the error, then use that.
			let userInfo = e.userInfo
			if let retry = userInfo[CKErrorRetryAfterKey] as? Double {
				print("ErrorHandler - \(message). Should retry in \(retry) seconds.")
				return .retry(afterSeconds: retry, message: message)
			} else {
				return .fail(reason: .unknown, message: message)
			}
			
		// RECOVERABLE ERROR
		case .networkUnavailable,
			 .networkFailure:
			print("ErrorHandler.recoverableError: \(message)")
			return .recoverableError(reason: .network, message: message)
		case .changeTokenExpired:
			print("ErrorHandler.recoverableError: \(message)")
			return .recoverableError(reason: .changeTokenExpired, message: message)
		case .serverRecordChanged:
			print("ErrorHandler.recoverableError: \(message)")
			return .recoverableError(reason: .serverRecordChanged, message: message)
		case .partialFailure:
			// Normally it shouldn't happen since if CKOperation `isAtomic` set to true
			if let dictionary = e.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary {
				print("ErrorHandler.partialFailure for \(dictionary.count) items; CKPartialErrorsByItemIDKey: \(dictionary)")
			}
			return .recoverableError(reason: .partialFailure, message: message)
			
		// SHOULD CHUNK IT UP
		case .limitExceeded:
			print("ErrorHandler.Chunk: \(message)")
			return .chunk
			
		// SHARE DATABASE RELATED
		case .alreadyShared,
			 .participantMayNeedVerification,
			 .referenceViolation,
			 .tooManyParticipants:
			print("ErrorHandler.Fail: \(message)")
			return .fail(reason: .shareRelated, message: message)
			
		// quota exceeded is sort of a special case where the user has to take action(like spare more room in iCloud) before retry
		case .quotaExceeded:
			print("ErrorHandler.Fail: \(message)")
			return .fail(reason: .quotaExceeded, message: message)
			
		// FAIL IS THE FINAL, WE REALLY CAN'T DO MORE
		default:
			print("ErrorHandler.Fail: \(message)")
			return .fail(reason: .unknown, message: message)
			
		}
		
	}
	
	func retryOperationIfPossible(retryAfter: Double, block: @escaping () -> ()) {
		let delayTime = DispatchTime.now() + retryAfter
		DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {
			block()
		})
	}
	
	private func returnErrorMessage(for code: CKError.Code) -> String {
		var returnMessage = ""
		
		switch code {
		case .alreadyShared:
			returnMessage = "Already Shared: a record or share cannot be saved because doing so would cause the same hierarchy of records to exist in multiple shares."
		case .assetFileModified:
			returnMessage = "Asset File Modified: the content of the specified asset file was modified while being saved."
		case .assetFileNotFound:
			returnMessage = "Asset File Not Found: the specified asset file is not found."
		case .badContainer:
			returnMessage = "Bad Container: the specified container is unknown or unauthorized."
		case .badDatabase:
			returnMessage = "Bad Database: the operation could not be completed on the given database."
		case .batchRequestFailed:
			returnMessage = "Batch Request Failed: the entire batch was rejected."
		case .changeTokenExpired:
			returnMessage = "Change Token Expired: the previous server change token is too old."
		case .constraintViolation:
			returnMessage = "Constraint Violation: the server rejected the request because of a conflict with a unique field."
		case .incompatibleVersion:
			returnMessage = "Incompatible Version: your app version is older than the oldest version allowed."
		case .internalError:
			returnMessage = "Internal Error: a nonrecoverable error was encountered by CloudKit."
		case .invalidArguments:
			returnMessage = "Invalid Arguments: the specified request contains bad information."
		case .limitExceeded:
			returnMessage = "Limit Exceeded: the request to the server is too large."
		case .managedAccountRestricted:
			returnMessage = "Managed Account Restricted: the request was rejected due to a managed-account restriction."
		case .missingEntitlement:
			returnMessage = "Missing Entitlement: the app is missing a required entitlement."
		case .networkUnavailable:
			returnMessage = "Network Unavailable: the internet connection appears to be offline."
		case .networkFailure:
			returnMessage = "Network Failure: the internet connection appears to be offline."
		case .notAuthenticated:
			returnMessage = "Not Authenticated: to use this app, you must enable iCloud syncing. Go to device Settings, sign in to iCloud, then in the app settings, be sure the iCloud feature is enabled."
		case .operationCancelled:
			returnMessage = "Operation Cancelled: the operation was explicitly canceled."
		case .partialFailure:
			returnMessage = "Partial Failure: some items failed, but the operation succeeded overall."
		case .participantMayNeedVerification:
			returnMessage = "Participant May Need Verification: you are not a member of the share."
		case .permissionFailure:
			returnMessage = "Permission Failure: to use this app, you must enable iCloud syncing. Go to device Settings, sign in to iCloud, then in the app settings, be sure the iCloud feature is enabled."
		case .quotaExceeded:
			returnMessage = "Quota Exceeded: saving would exceed your current iCloud storage quota."
		case .referenceViolation:
			returnMessage = "Reference Violation: the target of a record's parent or share reference was not found."
		case .requestRateLimited:
			returnMessage = "Request Rate Limited: transfers to and from the server are being rate limited at this time."
		case .serverRecordChanged:
			returnMessage = "Server Record Changed: the record was rejected because the version on the server is different."
		case .serverRejectedRequest:
			returnMessage = "Server Rejected Request"
		case .serverResponseLost:
			returnMessage = "Server Response Lost"
		case .serviceUnavailable:
			returnMessage = "Service Unavailable: Please try again."
		case .tooManyParticipants:
			returnMessage = "Too Many Participants: a share cannot be saved because too many participants are attached to the share."
		case .unknownItem:
			returnMessage = "Unknown Item:  the specified record does not exist."
		case .userDeletedZone:
			returnMessage = "User Deleted Zone: the user has deleted this zone from the settings UI."
		case .zoneBusy:
			returnMessage = "Zone Busy: the server is too busy to handle the zone operation."
		case .zoneNotFound:
			returnMessage = "Zone Not Found: the specified record zone does not exist on the server."
		default:
			returnMessage = "Unhandled Error."
		}
		
		return returnMessage + "CKError.Code: \(code.rawValue)"
	}
	
}

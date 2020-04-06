//
//  CloudKitResult.swift
//  Account
//
//  Created by Maurice Parker on 3/26/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit

enum CloudKitZoneResult {
	case success
	case retry(afterSeconds: Double)
	case limitExceeded
	case changeTokenExpired
	case partialFailure(errors: [CKRecord.ID: CKError])
	case serverRecordChanged
	case noZone
	case failure(error: Error)
	
	static func resolve(_ error: Error?) -> CloudKitZoneResult {
		
        guard error != nil else { return .success }
        
        guard let ckError = error as? CKError else {
            return .failure(error: error!)
        }
		
		switch ckError.code {
		case .serviceUnavailable, .requestRateLimited, .zoneBusy:
			if let retry = ckError.userInfo[CKErrorRetryAfterKey] as? Double {
				return .retry(afterSeconds: retry)
			} else {
				return .failure(error: error!)
			}
		case .changeTokenExpired:
			return .changeTokenExpired
		case .serverRecordChanged:
			return .serverRecordChanged
		case .partialFailure:
			if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: CKError] {
				if anyZoneErrors(partialErrors) {
					return .noZone
				} else {
					return .partialFailure(errors: partialErrors)
				}
			} else {
				return .failure(error: error!)
			}
		case .limitExceeded:
			return .limitExceeded
		default:
			return .failure(error: error!)
		}

	}
	
}

private extension CloudKitZoneResult {
	
	static func anyZoneErrors(_ errors: [CKRecord.ID: CKError]) -> Bool {
		return errors.values.contains(where: { $0.code == .zoneNotFound || $0.code == .userDeletedZone } )
	}
	
}

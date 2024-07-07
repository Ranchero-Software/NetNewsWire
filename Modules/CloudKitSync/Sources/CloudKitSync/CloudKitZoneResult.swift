//
//  CloudKitResult.swift
//  RSCore
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
	case partialFailure(errors: [AnyHashable: CKError])
	case serverRecordChanged
	case zoneNotFound
	case userDeletedZone
	case failure(error: Error)
	
	static func resolve(_ error: Error?) -> CloudKitZoneResult {
		
        guard error != nil else { return .success }
        
        guard let ckError = error as? CKError else {
            return .failure(error: error!)
        }
		
		switch ckError.code {
		case .serviceUnavailable, .requestRateLimited, .zoneBusy:
			if let retry = ckError.userInfo[CKErrorRetryAfterKey] as? NSNumber {
				return .retry(afterSeconds: retry.doubleValue)
			} else {
				return .failure(error: CloudKitError(ckError))
			}
		case .zoneNotFound:
			return .zoneNotFound
		case .userDeletedZone:
			return .userDeletedZone
		case .changeTokenExpired:
			return .changeTokenExpired
		case .serverRecordChanged:
			return .serverRecordChanged
		case .partialFailure:
			if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: CKError] {
				if let zoneResult = anyRequestErrors(partialErrors) {
					return zoneResult
				} else {
					return .partialFailure(errors: partialErrors)
				}
			} else {
				return .failure(error: CloudKitError(ckError))
			}
		case .limitExceeded:
			return .limitExceeded
		default:
			return .failure(error: CloudKitError(ckError))
		}

	}
	
}

private extension CloudKitZoneResult {
	
	static func anyRequestErrors(_ errors: [AnyHashable: CKError]) -> CloudKitZoneResult? {
		if errors.values.contains(where: { $0.code == .changeTokenExpired } ) {
			return .changeTokenExpired
		}
		if errors.values.contains(where: { $0.code == .zoneNotFound } ) {
			return .zoneNotFound
		}
		if errors.values.contains(where: { $0.code == .userDeletedZone } ) {
			return .userDeletedZone
		}
		return nil
	}
	
}

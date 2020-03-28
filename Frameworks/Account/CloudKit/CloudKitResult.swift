//
//  CloudKitResult.swift
//  Account
//
//  Created by Maurice Parker on 3/26/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit

enum CloudKitResult {
	case success
	case retry(afterSeconds: Double)
	case chunk
	case changeTokenExpired
	case partialFailure
	case serverRecordChanged
	case noZone
	case failure(error: Error)
	
	static func resolve(_ error: Error?) -> CloudKitResult {
		
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
			return .partialFailure
		case .limitExceeded:
			return .chunk
		case .zoneNotFound, .userDeletedZone:
			return .noZone
		default:
			return .failure(error: error!)
		}

	}
	
}

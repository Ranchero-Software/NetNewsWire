//
//  CloudKitError.swift
//  RSCore
//
//  Created by Maurice Parker on 3/26/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit

public final class CloudKitError: LocalizedError, Sendable {

	public let error: Error

	public init(_ error: Error) {
		self.error = error
	}

	public var errorDescription: String? {
		guard let ckError = error as? CKError else {
			return error.localizedDescription
		}

		let description = ckError.localizedDescription
		if let failureReason = (ckError as NSError).localizedFailureReason {
			return "\(description): \(failureReason)"
		}
		return description
	}

}

//
//  ReaderAPIError.swift
//  
//
//  Created by Brent Simmons on 4/6/24.
//

import Foundation

public enum ReaderAPIError: LocalizedError {

	case unknown
	case invalidParameter
	case invalidResponse
	case urlNotFound

	public var errorDescription: String? {
		switch self {
		case .unknown:
			return NSLocalizedString("An unexpected error occurred.", comment: "An unexpected error occurred.")
		case .invalidParameter:
			return NSLocalizedString("An invalid parameter was passed.", comment: "An invalid parameter was passed.")
		case .invalidResponse:
			return NSLocalizedString("There was an invalid response from the server.", comment: "There was an invalid response from the server.")
		case .urlNotFound:
			return NSLocalizedString("The API URL wasn't found.", comment: "The API URL wasn't found.")
		}
	}
}

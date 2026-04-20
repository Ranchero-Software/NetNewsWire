//
//  OPMLError.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

import Foundation

public enum OPMLError: LocalizedError {
	case dataIsWrongFormat(fileName: String)

	public var errorDescription: String? {
		switch self {
		case .dataIsWrongFormat(let fileName):
			return "The file ‘\(fileName)’ can’t be parsed because it’s not an OPML file."
		}
	}

	public var failureReason: String? {
		switch self {
		case .dataIsWrongFormat:
			return "The file is not an OPML file."
		}
	}
}

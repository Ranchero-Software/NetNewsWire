//
//  HTTPResponseCode.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct HTTPResponseCode {

	// http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
	// Not an enum because the main interest is the actual values.
	
	public static let responseContinue = 100 //"continue" is a language keyword, hence the weird name
	public static let switchingProtocols = 101
	
	public static let OK = 200
	public static let created = 201
	public static let accepted = 202
	public static let nonAuthoritativeInformation = 203
	public static let noContent = 204
	public static let resetContent = 205
	public static let partialContent = 206
	
	public static let redirectMultipleChoices = 300
	public static let redirectPermanent = 301
	public static let redirectTemporary = 302
	public static let redirectSeeOther = 303
	public static let notModified = 304
	public static let useProxy = 305
	public static let unused = 306
	public static let redirectVeryTemporary = 307
	
	public static let badRequest = 400
	public static let unauthorized = 401
	public static let paymentRequired = 402
	public static let forbidden = 403
	public static let notFound = 404
	public static let methodNotAllowed = 405
	public static let notAcceptable = 406
	public static let proxyAuthenticationRequired = 407
	public static let requestTimeout = 408
	public static let conflict = 409
	public static let gone = 410
	public static let lengthRequired = 411
	public static let preconditionFailed = 412
	public static let entityTooLarge = 413
	public static let URITooLong = 414
	public static let unsupportedMediaType = 415
	public static let requestedRangeNotSatisfiable = 416
	public static let expectationFailed = 417
	
	public static let internalServerError = 500
	public static let notImplemented = 501
	public static let badGateway = 502
	public static let serviceUnavailable = 503
	public static let gatewayTimeout = 504
	public static let HTTPVersionNotSupported = 505
}

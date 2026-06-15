//
//  URLSession+Webservice.swift
//  RSWeb
//
//  Created by Maurice Parker on 5/4/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//
import Foundation
import RSCore

public enum WebserviceError: LocalizedError, Sendable {
	case noData
    case noURL
	case suspended
	case httpError(status: Int)

	public var errorDescription: String? {
		switch self {
		case .httpError(let status):
			switch status {
			case 400:
				return NSLocalizedString("Bad Request", comment: "Bad Request")
			case 401:
				return NSLocalizedString("Unauthorized", comment: "Unauthorized")
			case 402:
				return NSLocalizedString("Payment Required", comment: "Payment Required")
			case 403:
				return NSLocalizedString("Forbidden", comment: "Forbidden")
			case 404:
				return NSLocalizedString("Not Found", comment: "Not Found")
			case 405:
				return NSLocalizedString("Method Not Allowed", comment: "Method Not Allowed")
			case 406:
				return NSLocalizedString("Not Acceptable", comment: "Not Acceptable")
			case 407:
				return NSLocalizedString("Proxy Authentication Required", comment: "Proxy Authentication Required")
			case 408:
				return NSLocalizedString("Request Timeout", comment: "Request Timeout")
			case 409:
				return NSLocalizedString("Conflict", comment: "Conflict")
			case 410:
				return NSLocalizedString("Gone", comment: "Gone")
			case 411:
				return NSLocalizedString("Length Required", comment: "Length Required")
			case 412:
				return NSLocalizedString("Precondition Failed", comment: "Precondition Failed")
			case 413:
				return NSLocalizedString("Payload Too Large", comment: "Payload Too Large")
			case 414:
				return NSLocalizedString("Request-URI Too Long", comment: "Request-URI Too Long")
			case 415:
				return NSLocalizedString("Unsupported Media Type", comment: "Unsupported Media Type")
			case 416:
				return NSLocalizedString("Requested Range Not Satisfiable", comment: "Requested Range Not Satisfiable")
			case 417:
				return NSLocalizedString("Expectation Failed", comment: "Expectation Failed")
			case 418:
				return NSLocalizedString("I'm a teapot", comment: "I'm a teapot")
			case 421:
				return NSLocalizedString("Misdirected Request", comment: "Misdirected Request")
			case 422:
				return NSLocalizedString("Unprocessable Entity", comment: "Unprocessable Entity")
			case 423:
				return NSLocalizedString("Locked", comment: "Locked")
			case 424:
				return NSLocalizedString("Failed Dependency", comment: "Failed Dependency")
			case 426:
				return NSLocalizedString("Upgrade Required", comment: "Upgrade Required")
			case 428:
				return NSLocalizedString("Precondition Required", comment: "Precondition Required")
			case 429:
				return NSLocalizedString("Too Many Requests", comment: "Too Many Requests")
			case 431:
				return NSLocalizedString("Request Header Fields Too Large", comment: "Request Header Fields Too Large")
			case 444:
				return NSLocalizedString("Connection Closed Without Response", comment: "Connection Closed Without Response")
			case 451:
				return NSLocalizedString("Unavailable For Legal Reasons", comment: "Unavailable For Legal Reasons")
			case 499:
				return NSLocalizedString("Client Closed Request", comment: "Client Closed Request")
			case 500:
				return NSLocalizedString("Internal Server Error", comment: "Internal Server Error")
			case 501:
				return NSLocalizedString("Not Implemented", comment: "Not Implemented")
			case 502:
				return NSLocalizedString("Bad Gateway", comment: "Bad Gateway")
			case 503:
				return NSLocalizedString("Service Unavailable", comment: "Service Unavailable")
			case 504:
				return NSLocalizedString("Gateway Timeout", comment: "Gateway Timeout")
			case 505:
				return NSLocalizedString("HTTP Version Not Supported", comment: "HTTP Version Not Supported")
			case 506:
				return NSLocalizedString("Variant Also Negotiates", comment: "Variant Also Negotiates")
			case 507:
				return NSLocalizedString("Insufficient Storage", comment: "Insufficient Storage")
			case 508:
				return NSLocalizedString("Loop Detected", comment: "Loop Detected")
			case 510:
				return NSLocalizedString("Not Extended", comment: "Not Extended")
			case 511:
				return NSLocalizedString("Network Authentication Required", comment: "Network Authentication Required")
			case 599:
				return NSLocalizedString("Network Connect Timeout Error", comment: "Network Connect Timeout Error")
			default:
				let msg = NSLocalizedString("HTTP Status: ", comment: "Unexpected error")
				return "\(msg) \(status)"
			}
		case .noData:
			return NSLocalizedString("No data was returned by the server.", comment: "No data")
		case .noURL:
			return NSLocalizedString("The URL for the request is missing.", comment: "No URL")
		case .suspended:
			return NSLocalizedString("The request was not sent because syncing is suspended.", comment: "Suspended")
		}
	}

}

nonisolated extension URLSession {

	/// The single shared session used for all web service calls.
	/// When running unit tests, it routes requests through `TestingURLProtocol`
	/// so no outside code needs any knowledge of testing.
	public static let webservice: URLSession = {

		let sessionConfiguration = URLSessionConfiguration.default
		sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
		sessionConfiguration.timeoutIntervalForRequest = 60.0
		sessionConfiguration.httpShouldSetCookies = false
		sessionConfiguration.httpCookieAcceptPolicy = .never
		sessionConfiguration.httpMaximumConnectionsPerHost = 1
		sessionConfiguration.httpCookieStorage = nil
		sessionConfiguration.urlCache = nil

		if let userAgentHeaders = UserAgent.headers() {
			sessionConfiguration.httpAdditionalHeaders = userAgentHeaders
		}

		if Platform.isRunningUnitTests {
			sessionConfiguration.protocolClasses = [TestingURLProtocol.self]
		}

		return URLSession(configuration: sessionConfiguration)
	}()

	public func cancelAll() {
		getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
			for task in dataTasks {
				task.cancel()
			}
			for task in uploadTasks {
				task.cancel()
			}
			for task in downloadTasks {
				task.cancel()
			}
		}
	}

	// These methods run on the cooperative thread pool, not the caller’s actor,
	// because the extension is nonisolated — so JSON decoding done by callers in
	// URLSession+WebserviceJSON happens off the main actor.

	@discardableResult
	public func send(request: URLRequest) async throws -> (HTTPURLResponse, Data?) {
		let (data, response) = try await data(for: request)
		return (try Self.validatedHTTPResponse(response), data)
	}

	public func send(request: URLRequest, method: String) async throws {
		var sendRequest = request
		sendRequest.httpMethod = method
		let (_, response) = try await data(for: sendRequest)
		_ = try Self.validatedHTTPResponse(response)
	}

	public func send(request: URLRequest, method: String, payload: Data) async throws -> (HTTPURLResponse, Data?) {
		var sendRequest = request
		sendRequest.httpMethod = method
		let (data, response) = try await upload(for: sendRequest, from: payload)
		return (try Self.validatedHTTPResponse(response), data)
	}

	/// Require an HTTP response with a 200...399 status code, or throw the matching `WebserviceError`.
	private static func validatedHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
		guard let httpResponse = response as? HTTPURLResponse else {
			throw WebserviceError.noData
		}
		switch httpResponse.forcedStatusCode {
		case 200...399:
			return httpResponse
		default:
			throw WebserviceError.httpError(status: httpResponse.forcedStatusCode)
		}
	}
}

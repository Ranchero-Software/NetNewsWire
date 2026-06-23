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
			return "HTTP \(status): \(HTTPURLResponse.localizedString(forStatusCode: status))"
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

	@discardableResult
	public func send(request: URLRequest) async throws -> (HTTPURLResponse, Data) {
		let (data, response) = try await data(for: request)
		return (try Self.validatedHTTPResponse(response), data)
	}

	public func send(request: URLRequest, method: String) async throws {
		var sendRequest = request
		sendRequest.httpMethod = method
		let (_, response) = try await data(for: sendRequest)
		try Self.validatedHTTPResponse(response)
	}

	public func send(request: URLRequest, method: String, payload: Data) async throws -> (HTTPURLResponse, Data) {
		var sendRequest = request
		sendRequest.httpMethod = method
		let (data, response) = try await upload(for: sendRequest, from: payload)
		return (try Self.validatedHTTPResponse(response), data)
	}

	/// Require an HTTP response with a 200...399 status code, or throw the matching `WebserviceError`.
	@discardableResult
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

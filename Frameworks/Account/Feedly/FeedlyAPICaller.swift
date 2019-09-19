//
//  FeedlyAPICaller.swift
//  Account
//
//  Created by Kiel Gillard on 13/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

final class FeedlyAPICaller {
	
	enum API {
		case sandbox
		case cloud
		
		static var `default`: API {
			return .sandbox
		}
		
		var baseUrlComponents: URLComponents {
			var components = URLComponents()
			components.scheme = "https"
			switch self{
			case .sandbox:
				// https://groups.google.com/forum/#!topic/feedly-cloud/WwQWMgDmOuw
				components.host = "sandbox7.feedly.com"
			case .cloud:
				// https://developer.feedly.com/cloud/
				components.host = "cloud.feedly.com"
			}
			return components
		}
	}
	
	private let transport: Transport
	private let baseUrlComponents: URLComponents
	
	init(transport: Transport, api: API) {
		self.transport = transport
		self.baseUrlComponents = api.baseUrlComponents
	}
	
	var credentials: Credentials?
	
	var server: String? {
		return baseUrlComponents.host
	}
}

extension FeedlyAPICaller: OAuthAuthorizationCodeGrantRequesting {
	
	static func authorizationCodeUrlRequest(for request: OAuthAuthorizationRequest) -> URLRequest {
		let api = API.default
		var components = api.baseUrlComponents
		components.path = "/v3/auth/auth"
		components.queryItems = request.queryItems
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		
		return request
	}
	
	typealias AccessTokenResponse = FeedlyOAuthAccessTokenResponse
	
	func requestAccessToken(_ authorizationRequest: OAuthAccessTokenRequest, completionHandler: @escaping (Result<FeedlyOAuthAccessTokenResponse, Error>) -> ()) {
		var components = baseUrlComponents
		components.path = "/v3/auth/token"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		
		do {
			let encoder = JSONEncoder()
			encoder.keyEncodingStrategy = .convertToSnakeCase
			request.httpBody = try encoder.encode(authorizationRequest)
		} catch {
			DispatchQueue.main.async {
				completionHandler(.failure(error))
			}
			return
		}
		
		transport.send(request: request, resultType: AccessTokenResponse.self, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (_, tokenResponse)):
				if let response = tokenResponse {
					completionHandler(.success(response))
				} else {
					completionHandler(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
}

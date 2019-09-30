//
//  TestTransport.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/4/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

final class TestTransport: Transport {
	
	enum TestTransportError: String, Error {
		case invalidState = "The test wasn't set up correctly."
	}
	
	var testFiles = [String: String]()
	var testStatusCodes = [String: Int]()
	
	private func httpResponse(for request: URLRequest, statusCode: Int = 200) -> HTTPURLResponse {
		guard let url = request.url else {
			fatalError("Attempting to mock a http response for a request without a URL \(request).")
		}
		return HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
	}
	
	func send(request: URLRequest, completion: @escaping (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
		
		guard let urlString = request.url?.absoluteString else {
			completion(.failure(TestTransportError.invalidState))
			return
		}
		
		let response = httpResponse(for: request, statusCode: testStatusCodes[urlString] ?? 200)
		
		if let testFileName = testFiles[urlString] {
			let testFileURL = Bundle(for: TestTransport.self).resourceURL!.appendingPathComponent(testFileName)
			let data = try! Data(contentsOf: testFileURL)
			DispatchQueue.global(qos: .background).async {
				completion(.success((response, data)))
			}
		} else {
			DispatchQueue.global(qos: .background).async {
				completion(.success((response, nil)))
			}
		}
		
	}

	func send(request: URLRequest, method: String, completion: @escaping (Result<Void, Error>) -> Void) {
		fatalError("Unimplemented.")
	}
	
	func send(request: URLRequest, method: String, payload: Data, completion: @escaping (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
		fatalError("Unimplemented.")
	}
}

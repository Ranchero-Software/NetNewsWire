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
	
	func send(request: URLRequest, completion: @escaping (Result<(HTTPHeaders, Data?), Error>) -> Void) {
		
		guard let urlString = request.url?.absoluteString else {
			completion(.failure(TestTransportError.invalidState))
			return
		}
		
		if let testFileName = testFiles[urlString] {
			let testFileURL = Bundle(for: TestTransport.self).resourceURL!.appendingPathComponent(testFileName)
			let data = try! Data(contentsOf: testFileURL)
			DispatchQueue.global(qos: .background).async {
				completion(.success((HTTPHeaders(), data)))
			}
		} else {
			DispatchQueue.global(qos: .background).async {
				completion(.success((HTTPHeaders(), nil)))
			}
		}
		
	}

	func send(request: URLRequest, payload: Data, completion: @escaping (Result<(HTTPHeaders, Data?), Error>) -> Void) {
		
	}
	
}

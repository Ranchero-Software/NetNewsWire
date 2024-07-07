//
//  TestTransport.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/4/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web
import XCTest

protocol TestTransportMockResponseProviding: AnyObject {
	func mockResponseFileUrl(for components: URLComponents) -> URL?
}

//final class TestTransport: Transport {
//	
//	enum TestTransportError: String, Error {
//		case invalidState = "The test wasn't set up correctly."
//	}
//	
//	var testFiles = [String: String]()
//	var testStatusCodes = [String: Int]()
//	
//	weak var mockResponseFileUrlProvider: TestTransportMockResponseProviding?
//	
//	private func httpResponse(for request: URLRequest, statusCode: Int = 200) -> HTTPURLResponse {
//		guard let url = request.url else {
//			fatalError("Attempting to mock a http response for a request without a URL \(request).")
//		}
//		return HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
//	}
//	
//	func cancelAll() { }
//	
//	func send(request: URLRequest, completion: @escaping (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
//		
//		guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
//			completion(.failure(TestTransportError.invalidState))
//			return
//		}
//		
//		let urlString = url.absoluteString
//		let response = httpResponse(for: request, statusCode: testStatusCodes[urlString] ?? 200)
//		let testFileURL: URL
//		
//		if let provider = mockResponseFileUrlProvider {
//			guard let providerUrl = provider.mockResponseFileUrl(for: components) else {
//				XCTFail("Test behaviour undefined. Mock provider failed to provide non-nil URL for \(components).")
//				return
//			}
//			testFileURL = providerUrl
//			
//		} else if let testKeyAndFileName = testFiles.first(where: { urlString.contains($0.key) }) {
//			testFileURL = Bundle.module.resourceURL!.appendingPathComponent(testKeyAndFileName.value)
//			
//		} else {
//			// XCTFail("Missing mock response for: \(urlString)")
//			print("***\nWARNING: \(self) missing mock response for:\n\(urlString)\n***")
//			DispatchQueue.global(qos: .background).async {
//				completion(.success((response, nil)))
//			}
//			return
//		}
//		
//		do {
//			let data = try Data(contentsOf: testFileURL)
//			DispatchQueue.global(qos: .background).async {
//				completion(.success((response, data)))
//			}
//		} catch {
//			XCTFail("Unable to read file at \(testFileURL) because \(error).")
//			DispatchQueue.global(qos: .background).async {
//				completion(.failure(error))
//			}
//		}
//	}
//
//	func send(request: URLRequest, method: String, completion: @escaping (Result<Void, Error>) -> Void) {
//		fatalError("Unimplemented.")
//	}
//	
//	func send(request: URLRequest, method: String, payload: Data, completion: @escaping (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
//		fatalError("Unimplemented.")
//	}
//}

//
//  TestingURLProtocol+Responses.swift
//  AccountTests
//
//  Helpers for registering canned responses with `TestingURLProtocol`,
//  which `URLSession.webservice` uses automatically while running unit tests.
//

import Foundation
import RSWeb

extension TestingURLProtocol {

	/// Register the response to return for any request whose URL contains `urlSubstring`.
	/// The body is loaded from `file`, relative to the test bundle resources (e.g. "JSON/tags_add.json").
	static func setResponse(_ urlSubstring: String, file: String, statusCode: Int = 200) {
		let fileURL = Bundle.module.resourceURL!.appendingPathComponent(file)
		let data: Data
		do {
			data = try Data(contentsOf: fileURL)
		} catch {
			fatalError("Unable to read response file at \(fileURL) because \(error).")
		}
		responses[urlSubstring] = Response(statusCode: statusCode, data: data)
	}
}

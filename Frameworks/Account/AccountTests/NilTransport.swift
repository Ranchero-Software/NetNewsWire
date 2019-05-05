//
//  NilTransport.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/4/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

struct NilTransport: Transport {
	
	func send<T>(request: URLRequest, resultType: T.Type, completion: @escaping (Result<(HTTPHeaders, T), Error>) -> Void) where T : Decodable, T : Encodable {
	}
	
	
	func send(request: URLRequest, completion: @escaping (Result<(HTTPHeaders, Data), Error>) -> Void) {
	}

}

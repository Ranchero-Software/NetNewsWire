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
	
	func send(request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
		completion(.success(Data()))
	}

}

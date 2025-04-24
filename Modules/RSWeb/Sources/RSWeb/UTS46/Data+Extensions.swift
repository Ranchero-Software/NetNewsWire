//
//  Data+Extensions.swift
//  PunyCocoa Swift
//
//  Created by Nate Weaver on 2020-04-12.
//

import Foundation
import zlib

extension Data {

	var crc32: UInt32 {
		return self.withUnsafeBytes {
			let buffer = $0.bindMemory(to: UInt8.self)
			let initial = zlib.crc32(0, nil, 0)
			return UInt32(zlib.crc32(initial, buffer.baseAddress, numericCast(buffer.count)))
		}
	}

}

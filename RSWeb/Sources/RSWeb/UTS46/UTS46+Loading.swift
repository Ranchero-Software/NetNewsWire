//
//  UTS46+Loading.swift
//  icumap2code
//
//  Created by Nate Weaver on 2020-05-08.
//

import Foundation
import Compression

extension UTS46 {

	private static func parseHeader(from data: Data) throws -> Header? {
		let headerData = data.prefix(8)

		guard headerData.count == 8 else { throw UTS46Error.badSize }

		return Header(rawValue: headerData)
	}

	static func load(from url: URL) throws {
		let fileData = try Data(contentsOf: url)

		guard let header = try? parseHeader(from: fileData) else { return }

		guard header.version == 1 else { throw UTS46Error.unknownVersion }

		let offset = header.dataOffset

		guard fileData.count > offset else { throw UTS46Error.badSize }

		let compressedData = fileData[offset...]

		guard let data = self.decompress(data: compressedData, algorithm: header.compression) else {
			throw UTS46Error.decompressionError
		}

		var index = 0

		while index < data.count {
			let marker = data[index]

			index += 1

			switch marker {
				case Marker.characterMap:
					index = parseCharacterMap(from: data, start: index)
				case Marker.ignoredCharacters:
					index = parseIgnoredCharacters(from: data, start: index)
				case Marker.disallowedCharacters:
					index = parseDisallowedCharacters(from: data, start: index)
				case Marker.joiningTypes:
					index = parseJoiningTypes(from: data, start: index)
				default:
					throw UTS46Error.badMarker
			}
		}

		isLoaded = true
	}

	static var bundle: Bundle {
		#if SWIFT_PACKAGE
		return Bundle.module
		#else
		return Bundle(for: Self.self)
		#endif
	}

	static func loadIfNecessary() throws {
		guard !isLoaded else { return }
		guard let url = Self.bundle.url(forResource: "uts46", withExtension: nil) else { throw CocoaError(.fileNoSuchFile) }

		try load(from: url)
	}

	private static func decompress(data: Data, algorithm: CompressionAlgorithm?) -> Data? {

		guard let rawAlgorithm = algorithm?.rawAlgorithm else { return data }

		let capacity = 131_072 // 128 KB
		let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)

		let decompressed = data.withUnsafeBytes { (rawBuffer) -> Data? in
			let bound = rawBuffer.bindMemory(to: UInt8.self)
			let decodedCount = compression_decode_buffer(destinationBuffer, capacity, bound.baseAddress!, rawBuffer.count, nil, rawAlgorithm)

			if decodedCount == 0 || decodedCount == capacity {
				return nil
			}

			return Data(bytes: destinationBuffer, count: decodedCount)
		}

		return decompressed
	}

	private static func parseCharacterMap(from data: Data, start: Int) -> Int {
		characterMap.removeAll()
		var index = start

		main: while index < data.count {
			var accumulator = Data()

			while data[index] != Marker.sequenceTerminator {
				if data[index] > Marker.min { break main }

				accumulator.append(data[index])
				index += 1
			}

			let str = String(data: accumulator, encoding: .utf8)!

			// FIXME: throw an error here.
			guard str.count > 0 else { continue }

			let codepoint = str.unicodeScalars.first!.value

			characterMap[codepoint] = String(str.unicodeScalars.dropFirst())

			index += 1
		}

		return index
	}

	private static func parseRanges(from: String) -> [ClosedRange<UnicodeScalar>]? {
		guard from.unicodeScalars.count % 2 == 0 else { return nil }

		var ranges = [ClosedRange<UnicodeScalar>]()
		var first: UnicodeScalar?

		for (index, scalar) in from.unicodeScalars.enumerated() {
			if index % 2 == 0 {
				first = scalar
			} else if let first = first {
				ranges.append(first...scalar)
			}
		}

		return ranges
	}

	static func parseCharacterSet(from data: Data, start: Int) -> (index: Int, charset: CharacterSet?) {
		var index = start
		var accumulator = Data()

		while index < data.count, data[index] < Marker.min {
			accumulator.append(data[index])
			index += 1
		}

		let str = String(data: accumulator, encoding: .utf8)!

		guard let ranges = parseRanges(from: str) else {
			return (index: index, charset: nil)
		}

		var charset = CharacterSet()

		for range in ranges {
			charset.insert(charactersIn: range)
		}

		return (index: index, charset: charset)
	}

	static func parseIgnoredCharacters(from data: Data, start: Int) -> Int {
		let (index, charset) = parseCharacterSet(from: data, start: start)

		if let charset = charset {
			ignoredCharacters = charset
		}

		return index
	}

	static func parseDisallowedCharacters(from data: Data, start: Int) -> Int {
		let (index, charset) = parseCharacterSet(from: data, start: start)

		if let charset = charset {
			disallowedCharacters = charset
		}

		return index
	}

	static func parseJoiningTypes(from data: Data, start: Int) -> Int {
		var index = start
		joiningTypes.removeAll()

		main: while index < data.count, data[index] < Marker.min {
			var accumulator = Data()

			while index < data.count {
				if data[index] > Marker.min { break main }
				accumulator.append(data[index])

				index += 1
			}

			let str = String(data: accumulator, encoding: .utf8)!

			var type: JoiningType?
			var first: UnicodeScalar?

			for scalar in str.unicodeScalars {
				if scalar.isASCII {
					type = JoiningType(rawValue: Character(scalar))
				} else if let type = type {
					if first == nil {
						first = scalar
					} else {
						for value in first!.value...scalar.value {
							joiningTypes[value] = type
						}

						first = nil
					}
				}
			}
		}

		return index
	}

}

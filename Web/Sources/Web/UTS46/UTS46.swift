//
//  UTS46.swift
//  PunyCocoa Swift
//
//  Created by Nate Weaver on 2020-03-29.
//

import Foundation
import Compression

/// UTS46 mapping.
///
/// Storage file format. Codepoints are stored UTF-8-encoded.
///
/// All multibyte integers are little-endian.
///
/// Header:
///
///     +--------------+---------+---------+---------+
///     | 6 bytes      | 1 byte  | 1 byte  | 4 bytes |
///     +--------------+---------+---------+---------+
///     | magic number | version | flags   | crc32   |
///     +--------------+---------+---------+---------+
///
/// - `magic number`: `"UTS#46"` (`0x55 0x54 0x53 0x23 0x34 0x36`).
/// - `version`: format version (1 byte; currently `0x01`).
/// - `flags`: Bitfield:
///
///       +-----+-----+-----+-----+-----+-----+-----+-----+
///       |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |
///       +-----+-----+-----+-----+-----+-----+-----+-----+
///       | currently unused      | crc | compression     |
///       +-----+-----+-----+-----+-----+-----+-----+-----+
///
///     - `crc`: Contains a CRC32 of the data after the header.
///     - `compression`: compression mode of the data.
///       Currently identical to NSData's compression constants + 1:
///
///       - 0: no compression
///       - 1: LZFSE
///       - 2: LZ4
///       - 3: LZMA
///       - 4: ZLIB
///
/// - `crc32`: CRC32 of the (possibly compressed) data. Implementations can skip
///   parsing this unless data integrity is an issue.
///
/// The data section is a collection of data blocks of the format
///
///     [marker][section data] ...
///
/// Section data formats:
///
/// If marker is `characterMap`:
///
///     [codepoint][mapped-codepoint ...][null] ...
///
/// If marker is `disallowedCharacters` or `ignoredCharacters`:
///
///     [codepoint-range] ...
///
/// If marker is `joiningTypes`:
///
///     [type][[codepoint-range] ...]
///
/// where `type` is one of `C`, `D`, `L`, `R`, or `T`.
///
/// `codepoint-range`: two codepoints, marking the first and last codepoints of a
/// closed range. Single-codepoint ranges have the same start and end codepoint.
///
class UTS46 {

	static var characterMap: [UInt32: String] = [:]
	static var ignoredCharacters: CharacterSet = []
	static var disallowedCharacters: CharacterSet = []
	static var joiningTypes = [UInt32: JoiningType]()

	static var isLoaded = false

	enum Marker {
		static let characterMap = UInt8.max
		static let ignoredCharacters = UInt8.max - 1
		static let disallowedCharacters = UInt8.max - 2
		static let joiningTypes = UInt8.max - 3

		static let min = UInt8.max - 10 // No valid UTF-8 byte can fall here.

		static let sequenceTerminator: UInt8 = 0
	}

	enum JoiningType: Character {
		case causing = "C"
		case dual = "D"
		case right = "R"
		case left = "L"
		case transparent = "T"
	}

	enum UTS46Error: Error {
		case badSize
		case compressionError
		case decompressionError
		case badMarker
		case unknownVersion
	}

	/// Identical values to `NSData.CompressionAlgorithm + 1`.
	enum CompressionAlgorithm: UInt8 {
		case none = 0
		case lzfse = 1
		case lz4 = 2
		case lzma = 3
		case zlib = 4

		var rawAlgorithm: compression_algorithm? {
			switch self {
				case .lzfse:
					return COMPRESSION_LZFSE
				case .lz4:
					return COMPRESSION_LZ4
				case .lzma:
					return COMPRESSION_LZMA
				case .zlib:
					return COMPRESSION_ZLIB
				default:
					return nil
			}
		}
	}

	struct Header: RawRepresentable, CustomDebugStringConvertible {
		typealias RawValue = [UInt8]

		var rawValue: [UInt8] {
			let value = Self.signature + [version, flags.rawValue]
			assert(value.count == 8)
			return value
		}

		private static let compressionMask: UInt8 = 0x07
		private static let signature: [UInt8] = Array("UTS#46".utf8)

		private struct Flags: RawRepresentable {
			var rawValue: UInt8 {
				return (hasCRC ? hasCRCMask : 0) | compression.rawValue
			}

			var hasCRC: Bool
			var compression: CompressionAlgorithm

			private let hasCRCMask: UInt8 = 1 << 3
			private let compressionMask: UInt8 = 0x7

			init(rawValue: UInt8) {
				hasCRC = rawValue & hasCRCMask != 0
				let compressionBits = rawValue & compressionMask

				compression = CompressionAlgorithm(rawValue: compressionBits) ?? .none
			}

			init(compression: CompressionAlgorithm = .none, hasCRC: Bool = false) {
				self.compression = compression
				self.hasCRC = hasCRC
			}
		}

		let version: UInt8
		private var flags: Flags
		var hasCRC: Bool { flags.hasCRC }
		var compression: CompressionAlgorithm { flags.compression }
		var dataOffset: Int { 8 + (flags.hasCRC ? 4 : 0) }

		init?<T: DataProtocol>(rawValue: T) where T.Index == Int {
			guard rawValue.count == 8 else { return nil }
			guard rawValue.prefix(Self.signature.count).elementsEqual(Self.signature) else { return nil }

			version = rawValue[rawValue.index(rawValue.startIndex, offsetBy: 6)]
			flags = Flags(rawValue: rawValue[rawValue.index(rawValue.startIndex, offsetBy: 7)])
		}

		init(compression: CompressionAlgorithm = .none, hasCRC: Bool = false) {
			self.version = 1
			self.flags = Flags(compression: compression, hasCRC: hasCRC)
		}

		var debugDescription: String { "has CRC: \(hasCRC); compression: \(String(describing: compression))" }
	}

}

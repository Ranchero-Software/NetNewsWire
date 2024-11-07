//
//  String+Punycode.swift
//  Punycode
//
//  Created by Nate Weaver on 2020-03-16.
//

import Foundation

public extension String {

	/// The IDNA-encoded representation of a Unicode domain.
	///
	/// This will properly split domains on periods; e.g.,
	/// "www.bücher.ch" becomes "www.xn--bcher-kva.ch".
	var idnaEncoded: String? {
		guard let mapped = try? self.mapUTS46() else { return nil }

		let nonASCII = CharacterSet(charactersIn: UnicodeScalar(0)...UnicodeScalar(127)).inverted
		var result = ""

		let s = Scanner(string: mapped.precomposedStringWithCanonicalMapping)
		let dotAt = CharacterSet(charactersIn: ".@")

		while !s.isAtEnd {
			if let input = s.shimScanUpToCharacters(from: dotAt) {
				if !input.isValidLabel { return nil }

				if input.rangeOfCharacter(from: nonASCII) != nil {
					result.append("xn--")

					if let encoded = input.punycodeEncoded {
						result.append(encoded)
					}
				} else {
					result.append(input)
				}
			}

			if let input = s.shimScanCharacters(from: dotAt) {
				result.append(input)
			}
		}

		return result
	}

	/// The Unicode representation of an IDNA-encoded domain.
	///
	/// This will properly split domains on periods; e.g.,
	/// "www.xn--bcher-kva.ch" becomes "www.bücher.ch".
	var idnaDecoded: String? {
		var result = ""
		let s = Scanner(string: self)
		let dotAt = CharacterSet(charactersIn: ".@")

		while !s.isAtEnd {
			if let input = s.shimScanUpToCharacters(from: dotAt) {
				if input.lowercased().hasPrefix("xn--") {
					let start = input.index(input.startIndex, offsetBy: 4)
					guard let substr = input[start...].punycodeDecoded else { return nil }
					guard substr.isValidLabel else { return nil }
					result.append(substr)
				} else {
					result.append(input)
				}
			}

			if let input = s.shimScanCharacters(from: dotAt) {
				result.append(input)
			}
		}

		return result
	}

	/// The IDNA- and percent-encoded representation of a URL string.
	var encodedURLString: String? {
		let urlParts = self.urlParts
		var pathAndQuery = urlParts.pathAndQuery

		var allowedCharacters = CharacterSet.urlPathAllowed
		allowedCharacters.insert(charactersIn: "%?")
		pathAndQuery = pathAndQuery.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""

		var result = "\(urlParts.scheme)\(urlParts.delim)"

		if let username = urlParts.username?.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) {
			if let password = urlParts.password?.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) {
				result.append("\(username):\(password)@")
			} else {
				result.append("\(username)@")
			}
		}

		guard let host = urlParts.host.idnaEncoded else { return nil }

		result.append("\(host)\(pathAndQuery)")

		if var fragment = urlParts.fragment {
			var fragmentAlloweCharacters = CharacterSet.urlFragmentAllowed
			fragmentAlloweCharacters.insert(charactersIn: "%")
			fragment = fragment.addingPercentEncoding(withAllowedCharacters: fragmentAlloweCharacters) ?? ""

			result.append("#\(fragment)")
		}

		return result
	}

	/// The Unicode representation of an IDNA- and percent-encoded URL string.
	var decodedURLString: String? {
		let urlParts = self.urlParts
		var usernamePassword = ""

		if let username = urlParts.username?.removingPercentEncoding {
			if let password = urlParts.password?.removingPercentEncoding {
				usernamePassword = "\(username):\(password)@"
			} else {
				usernamePassword = "\(username)@"
			}
		}

		guard let host = urlParts.host.idnaDecoded else { return nil }

		var result = "\(urlParts.scheme)\(urlParts.delim)\(usernamePassword)\(host)\(urlParts.pathAndQuery.removingPercentEncoding ?? "")"

		if let fragment = urlParts.fragment?.removingPercentEncoding {
			result.append("#\(fragment)")
		}

		return result
	}

}

public extension URL {

	/// Initializes a URL with a Unicode URL string.
	///
	/// If `unicodeString` can be successfully encoded, equivalent to
	///
	/// ```
	/// URL(string: unicodeString.encodedURLString!)
	/// ```
	///
	/// - Parameter unicodeString: The unicode URL string with which to create a URL.
	init?(unicodeString: String) {
		if let url = URL(string: unicodeString) {
			self = url
			return
		}

		guard let encodedString = unicodeString.encodedURLString else { return nil }
		self.init(string: encodedString)
	}

	/// The IDNA- and percent-decoded representation of the URL.
	///
	/// Equivalent to
	///
	///	```
	/// self.absoluteString.decodedURLString
	/// ```
	var decodedURLString: String? {
		return self.absoluteString.decodedURLString
	}

	/// Initializes a URL from a relative Unicode string and a base URL.
	/// - Parameters:
	///   - unicodeString: The URL string with which to initialize the NSURL object. `unicodeString` is interpreted relative to `baseURL`.
	///   - url: The base URL for the URL object
	init?(unicodeString: String, relativeTo url: URL?) {
		if let url = URL(string: unicodeString, relativeTo: url) {
			self = url
			return
		}

		let parts = unicodeString.urlParts

		if !parts.host.isEmpty {
			guard let encodedString = unicodeString.encodedURLString else { return nil }
			self.init(string: encodedString, relativeTo: url)
		} else {
			var allowedCharacters = CharacterSet.urlPathAllowed
			allowedCharacters.insert(charactersIn: "%?#")
			guard let encoded = unicodeString.addingPercentEncoding(withAllowedCharacters: allowedCharacters) else { return nil }
			self.init(string: encoded, relativeTo: url)
		}
	}

}

private extension StringProtocol {

	/// Punycode-encodes a string.
	///
	/// Returns `nil` on error.
	/// - Todo: Throw errors on failure instead of returning `nil`.
	var punycodeEncoded: String? {
		var result = ""
		let scalars = self.unicodeScalars
		let inputLength = scalars.count

		var n = Punycode.initialN
		var delta: UInt32 = 0
		var outLen: UInt32 = 0
		var bias = Punycode.initialBias

		for scalar in scalars where scalar.isASCII {
			result.unicodeScalars.append(scalar)
			outLen += 1
		}

		let b: UInt32 = outLen
		var h: UInt32 = outLen

		if b > 0 {
			result.append(Punycode.delimiter)
		}

		// Main encoding loop:

		while h < inputLength {
			var m = UInt32.max

			for c in scalars {
				if c.value >= n && c.value < m {
					m = c.value
				}
			}

			if m - n > (UInt32.max - delta) / (h + 1) {
				return nil // overflow
			}

			delta += (m - n) * (h + 1)
			n = m

			for c in scalars {

				if c.value < n {
					delta += 1

					if delta == 0 {
						return nil // overflow
					}
				}

				if c.value == n {
					var q = delta
					var k = Punycode.base

					while true {
						let t = k <= bias ? Punycode.tmin :
							k >= bias + Punycode.tmax ? Punycode.tmax : k - bias

						if q < t {
							break
						}

						let encodedDigit = Punycode.encodeDigit(t + (q - t) % (Punycode.base - t), flag: false)

						result.unicodeScalars.append(UnicodeScalar(encodedDigit)!)
						q = (q - t) / (Punycode.base - t)

						k += Punycode.base
					}

					result.unicodeScalars.append(UnicodeScalar(Punycode.encodeDigit(q, flag: false))!)
					bias = Punycode.adapt(delta: delta, numPoints: h + 1, firstTime: h == b)
					delta = 0
					h += 1
				}
			}

			delta += 1
			n += 1
		}

		return result
	}

	/// Punycode-decodes a string.
	///
	/// Returns `nil` on error.
	/// - Todo: Throw errors on failure instead of returning `nil`.
	var punycodeDecoded: String? {
		var result = ""
		let scalars = self.unicodeScalars

		let endIndex = scalars.endIndex
		var n = Punycode.initialN
		var outLen: UInt32 = 0
		var i: UInt32 = 0
		var bias = Punycode.initialBias

		var b = scalars.startIndex

		for j in scalars.indices {
			if Character(self.unicodeScalars[j]) == Punycode.delimiter {
				b = j
				break
			}
		}

		for j in scalars.indices {
			if j >= b {
				break
			}

			let scalar = scalars[j]

			if !scalar.isASCII {
				return nil // bad input
			}

			result.unicodeScalars.append(scalar)
			outLen += 1

		}

		var inPos = b > scalars.startIndex ? scalars.index(after: b) : scalars.startIndex

		while inPos < endIndex {

			var k = Punycode.base
			var w: UInt32 = 1
			let oldi = i

			while true {
				if inPos >= endIndex {
					return nil // bad input
				}

				let digit = Punycode.decodeDigit(scalars[inPos].value)

				inPos = scalars.index(after: inPos)

				if digit >= Punycode.base { return nil } // bad input
				if digit > (UInt32.max - i) / w { return nil } // overflow

				i += digit * w
				let t = k <= bias ? Punycode.tmin :
					k >= bias + Punycode.tmax ? Punycode.tmax : k - bias

				if digit < t {
					break
				}

				if w > UInt32.max / (Punycode.base - t) { return nil } // overflow

				w *= Punycode.base - t

				k += Punycode.base
			}

			bias = Punycode.adapt(delta: i - oldi, numPoints: outLen + 1, firstTime: oldi == 0)

			if i / (outLen + 1) > UInt32.max - n { return nil } // overflow

			n += i / (outLen + 1)
			i %= outLen + 1

			let index = result.unicodeScalars.index(result.unicodeScalars.startIndex, offsetBy: Int(i))
			result.unicodeScalars.insert(UnicodeScalar(n)!, at: index)
			
			outLen += 1
			i += 1
		}

		return result
	}

}

private extension String {

	var urlParts: URLParts {
		let colonSlash = CharacterSet(charactersIn: ":/")
		let slashQuestion = CharacterSet(charactersIn: "/?")
		let s = Scanner(string: self)
		var scheme = ""
		var delim = ""
		var host = ""
		var path = ""
		var username: String?
		var password: String?
		var fragment: String?

		if let hostOrScheme = s.shimScanUpToCharacters(from: colonSlash) {
			let maybeDelim = s.shimScanCharacters(from: colonSlash) ?? ""

			if maybeDelim.hasPrefix(":") {
				delim = maybeDelim
				scheme = hostOrScheme
				host = s.shimScanUpToCharacters(from: slashQuestion) ?? ""
			} else {
				path.append(hostOrScheme)
				path.append(maybeDelim)
			}
		} else if let maybeDelim = s.shimScanString("//") {
			delim = maybeDelim

			if let maybeHost = s.shimScanUpToCharacters(from: slashQuestion) {
				host = maybeHost
			}
		}

		path.append(s.shimScanUpToString("#") ?? "")

		if s.shimScanString("#") != nil {
			fragment = s.shimScanUpToCharacters(from: .newlines) ?? ""
		}

		let usernamePasswordHostPort = host.components(separatedBy: "@")

		switch usernamePasswordHostPort.count {
			case 1:
				host = usernamePasswordHostPort[0]
			case 0:
				break // error
			default:
				let usernamePassword = usernamePasswordHostPort[0].components(separatedBy: ":")
				username = usernamePassword[0]
				password = usernamePassword.count > 1 ? usernamePassword[1] : nil
				host = usernamePasswordHostPort[1]
		}

		return URLParts(scheme: scheme, delim: delim, host: host, pathAndQuery: path, username: username, password: password, fragment: fragment)
	}

	enum UTS46MapError: Error {
		/// A disallowed codepoint was found in the string.
		case disallowedCodepoint(scalar: UnicodeScalar)
	}

	/// Perform a single-pass mapping using UTS #46.
	///
	/// - Returns: The mapped string.
	/// - Throws: `UTS46Error`.
	func mapUTS46() throws -> String {
		try UTS46.loadIfNecessary()

		var result = ""

		for scalar in self.unicodeScalars {
			if UTS46.disallowedCharacters.contains(scalar) {
				throw UTS46MapError.disallowedCodepoint(scalar: scalar)
			}

			if UTS46.ignoredCharacters.contains(scalar) {
				continue
			}

			if let mapped = UTS46.characterMap[scalar.value] {
				result.append(mapped)
			} else {
				result.unicodeScalars.append(scalar)
			}
		}

		return result
	}

	var isValidLabel: Bool {
		guard self.precomposedStringWithCanonicalMapping.unicodeScalars.elementsEqual(self.unicodeScalars) else { return false }

		guard (try? self.mapUTS46()) != nil else { return false }

		if let category = self.unicodeScalars.first?.properties.generalCategory {
			if category == .nonspacingMark || category == .spacingMark || category == .enclosingMark { return false }
		}

		return self.hasValidJoiners
	}

	/// Whether a string's joiners (if any) are valid according to IDNA 2008 ContextJ.
	///
	/// See [RFC 5892, Appendix A.1 and A.2](https://tools.ietf.org/html/rfc5892#appendix-A).
	var hasValidJoiners: Bool {
		try! UTS46.loadIfNecessary()
		
		let scalars = self.unicodeScalars

		for index in scalars.indices {
			let scalar = scalars[index]

			if scalar.value == 0x200C { // Zero-width non-joiner
				if index == scalars.indices.first { return false }

				var subindex = scalars.index(before: index)
				var previous = scalars[subindex]

				if previous.properties.canonicalCombiningClass == .virama { continue }

				while true {
					guard let joiningType = UTS46.joiningTypes[previous.value] else { return false }

					if joiningType == .transparent {
						if subindex == scalars.startIndex {
							return false
						}

						subindex = scalars.index(before: subindex)
						previous = scalars[subindex]
					} else if joiningType == .dual || joiningType == .left {
						break
					} else {
						return false
					}
				}

				subindex = scalars.index(after: index)
				var next = scalars[subindex]

				while true {
					if subindex == scalars.endIndex {
						return false
					}

					guard let joiningType = UTS46.joiningTypes[next.value] else { return false }

					if joiningType == .transparent {
						subindex = scalars.index(after: index)
						next = scalars[subindex]
					} else if joiningType == .right || joiningType == .dual {
						break
					} else {
						return false
					}
				}
			} else if scalar.value == 0x200D { // Zero-width joiner
				if index == scalars.startIndex { return false }

				let subindex = scalars.index(before: index)
				let previous = scalars[subindex]

				if previous.properties.canonicalCombiningClass != .virama { return false }
			}
		}

		return true
	}

}

private enum Punycode {
	static let base = UInt32(36)
	static let tmin = UInt32(1)
	static let tmax = UInt32(26)
	static let skew = UInt32(38)
	static let damp = UInt32(700)
	static let initialBias = UInt32(72)
	static let initialN = UInt32(0x80)
	static let delimiter: Character = "-"

	static func decodeDigit(_ cp: UInt32) -> UInt32 {
		return cp &- 48 < 10 ? cp &- 22 : cp &- 65 < 26 ? cp &- 65 :
			cp &- 97 < 26 ? cp &- 97 : Self.base
	}

	static func encodeDigit(_ d: UInt32, flag: Bool) -> UInt32 {
		return d + 22 + 75 * UInt32(d < 26 ? 1 : 0) - ((flag ? 1 : 0) << 5)
	}

	static let maxint = UInt32.max

	static func adapt(delta: UInt32, numPoints: UInt32, firstTime: Bool) -> UInt32 {

		var delta = delta

		delta = firstTime ? delta / Self.damp : delta >> 1
		delta += delta / numPoints

		var k: UInt32 = 0

		while delta > ((Self.base - Self.tmin) * Self.tmax) / 2 {
			delta /= Self.base - Self.tmin
			k += Self.base
		}

		return k + (Self.base - Self.tmin + 1) * delta / (delta + Self.skew)
	}
}

private struct URLParts {
	var scheme: String
	var delim: String
	var host: String
	var pathAndQuery: String

	var username: String?
	var password: String?
	var fragment: String?
}

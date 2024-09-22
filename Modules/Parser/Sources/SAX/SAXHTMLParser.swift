//
//  SAXHTMLParser.swift
//  
//
//  Created by Brent Simmons on 8/26/24.
//

import Foundation
import libxml2

public protocol SAXHTMLParserDelegate: AnyObject {

	func saxHTMLParser(_: SAXHTMLParser, startElement: XMLPointer, attributes: UnsafePointer<XMLPointer?>?)

	func saxHTMLParser(_: SAXHTMLParser, endElement: XMLPointer)

	// Length is guaranteed to be greater than 0.
	func saxHTMLParser(_: SAXHTMLParser, charactersFound: XMLPointer, count: Int)
}

public final class SAXHTMLParser {

	fileprivate let delegate: SAXHTMLParserDelegate

	public var currentCharacters: Data? { // UTF-8 encoded

		guard storingCharacters else {
			return nil
		}
		return characters
	}

	// Conveniences to get string version of currentCharacters

	public var currentString: String? {

		guard let d = currentCharacters, !d.isEmpty else {
			return nil
		}
		return String(data: d, encoding: .utf8)
	}

	public var currentStringWithTrimmedWhitespace: String? {

		guard let s = currentString else {
			return nil
		}
		return s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
	}

	private var data: Data
	private var storingCharacters = false
	private var characters = Data()

	public init(delegate: SAXHTMLParserDelegate, data: Data) {

		self.delegate = delegate
		self.data = data
	}

	public func parse() {

		guard !data.isEmpty else {
			return
		}

		data.withUnsafeBytes { bufferPointer in

			guard let bytes = bufferPointer.bindMemory(to: xmlChar.self).baseAddress else {
				return
			}

			let characterEncoding = xmlDetectCharEncoding(bytes, Int32(data.count))
			let context = htmlCreatePushParserCtxt(&saxHandlerStruct, Unmanaged.passUnretained(self).toOpaque(), nil, 0, nil, characterEncoding)
			htmlCtxtUseOptions(context, Int32(XML_PARSE_RECOVER.rawValue | XML_PARSE_NONET.rawValue | HTML_PARSE_COMPACT.rawValue))

			htmlParseChunk(context, bytes, Int32(data.count), 0)

			htmlParseChunk(context, nil, 0, 1)
			htmlFreeParserCtxt(context)
		}
	}

	/// Delegate can call from xmlStartElement. Characters will be available in xmlEndElement as currentCharacters property. Storing characters is stopped after each xmlEndElement.
	public func beginStoringCharacters() {

		storingCharacters = true
		characters.count = 0
	}

	public func endStoringCharacters() {

		storingCharacters = false
		characters.count = 0
	}

	public typealias HTMLAttributesDictionary = [String: String]

	public func attributesDictionary(_ attributes: UnsafePointer<XMLPointer?>?) -> HTMLAttributesDictionary? {

		guard let attributes else {
			return nil
		}

		var dictionary = [String: String]()
		var ix = 0
		var currentKey: String? = nil

		while true {
			let oneAttribute = attributes[ix]
			ix += 1

			if currentKey == nil && oneAttribute == nil {
				break
			}

			if currentKey == nil {
				if let oneAttribute {
					currentKey = String(cString: oneAttribute)
				}
			} else {
				let value: String?
				if let oneAttribute {
					value = String(cString: oneAttribute)
				} else {
					value = nil
				}

				dictionary[currentKey!] = value ?? ""
				currentKey = nil
			}
		}

		return dictionary
	}
}

private extension SAXHTMLParser {

	func charactersFound(_ htmlCharacters: XMLPointer, count: Int) {

		if storingCharacters {
			characters.append(htmlCharacters, count: count)
		}

		delegate.saxHTMLParser(self, charactersFound: htmlCharacters, count: count)
	}

	func startElement(_ name: XMLPointer, attributes: UnsafePointer<XMLPointer?>?) {

		delegate.saxHTMLParser(self, startElement: name, attributes: attributes)
	}

	func endElement(_ name: XMLPointer) {

		delegate.saxHTMLParser(self, endElement: name)
		endStoringCharacters()
	}
}

private func startElement(_ context: UnsafeMutableRawPointer?, name: XMLPointer?, attributes: UnsafeMutablePointer<XMLPointer?>?) {

	guard let context, let name else {
		return
	}

	let parser = parser(from: context)
	parser.startElement(name, attributes: attributes)
}


private func endElement(_ context: UnsafeMutableRawPointer?, name: XMLPointer?) {

	guard let context, let name else {
		return
	}

	let parser = parser(from: context)
	parser.endElement(name)
}

private func charactersFound(_ context: UnsafeMutableRawPointer?, ch: XMLPointer?, len: CInt) {

	guard let context, let ch, len > 0 else {
		return
	}

	let parser = parser(from: context)
	parser.charactersFound(ch, count: Int(len))
}

private func parser(from context: UnsafeMutableRawPointer) -> SAXHTMLParser {

	Unmanaged<SAXHTMLParser>.fromOpaque(context).takeUnretainedValue()
}

nonisolated(unsafe) private var saxHandlerStruct: xmlSAXHandler = {

	var handler = xmlSAXHandler()

	handler.characters = charactersFound
	handler.startElement = startElement
	handler.endElement = endElement
	handler.initialized = XML_SAX2_MAGIC

	return handler
}()

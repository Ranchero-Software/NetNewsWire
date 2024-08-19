//
//  SAXParser.swift.
//
//
//  Created by Brent Simmons on 8/12/24.
//

import Foundation
import libxml2

typealias XMLPointer = UnsafePointer<xmlChar>

protocol SAXParserDelegate {

	func saxParser(_: SAXParser, xmlStartElement: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?, namespaceCount: Int, namespaces: UnsafeMutablePointer<XMLPointer?>?, attributeCount: Int, attributesDefaultedCount: Int, attributes: UnsafeMutablePointer<XMLPointer?>?)

	func saxParser(_: SAXParser, xmlEndElement: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?)

	func saxParser(_: SAXParser, xmlCharactersFound: XMLPointer, count: Int)

	func saxParser(_: SAXParser, internedStringForName: XMLPointer, prefix: XMLPointer?) -> String?

	func saxParser(_: SAXParser, internedStringForValue: XMLPointer, count: Int) -> String?
}

final class SAXParser {

	fileprivate let delegate: SAXParserDelegate

	var currentCharacters: Data? { // UTF-8 encoded

		guard storingCharacters else {
			return nil
		}
		return characters
	}

	// Conveniences to get string version of currentCharacters

	var currentString: String? {

		guard let d = currentCharacters, !d.isEmpty else {
			return nil
		}
		return String(data: d, encoding: .utf8)
	}

	var currentStringWithTrimmedWhitespace: String? {

		guard let s = currentString else {
			return nil
		}
		return s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
	}

	private var data: Data
	private var storingCharacters = false
	private var characters = Data()

	init(delegate: SAXParserDelegate, data: Data) {

		self.delegate = delegate
		self.data = data
	}

	func parse() {
		
		guard !data.isEmpty else {
			return
		}

		let context = xmlCreatePushParserCtxt(&saxHandlerStruct, Unmanaged.passUnretained(self).toOpaque(), nil, 0, nil)
		xmlCtxtUseOptions(context, Int32(XML_PARSE_RECOVER.rawValue | XML_PARSE_NOENT.rawValue))

		data.withUnsafeBytes { bufferPointer in
			if let bytes = bufferPointer.bindMemory(to: CChar.self).baseAddress {
				xmlParseChunk(context, bytes, CInt(data.count), 0)
			}
		}

		xmlParseChunk(context, nil, 0, 1)
		xmlFreeParserCtxt(context)
	}

	/// Delegate can call from xmlStartElement. Characters will be available in xmlEndElement as currentCharacters property. Storing characters is stopped after each xmlEndElement.
	func beginStoringCharacters() {

		storingCharacters = true
		characters.count = 0
	}

	func endStoringCharacters() {

		storingCharacters = false
		characters.count = 0
	}

	func attributesDictionary(_ attributes: UnsafePointer<XMLPointer?>?, attributeCount: Int) -> [String: String]? {

		guard attributeCount > 0, let attributes else {
			return nil
		}

		var dictionary = [String: String]()
		
		let fieldCount = 5
		var i = 0, j = 0
		while i < attributeCount {

			guard let attribute = attributes[j] else {
				continue
			}
			let prefix = attributes[j + 1]
			var attributeName = delegate.saxParser(self, internedStringForName: attribute, prefix: prefix)
			if attributeName == nil {
				attributeName = String(cString: attribute)
				if let prefix {
					let attributePrefix = String(cString: prefix)
					attributeName = "\(attributePrefix):\(attributeName!)"
				}
			}

			guard let valueStart = attributes[j + 3], let valueEnd = attributes[j + 4] else {
				continue
			}
			let valueCount = valueEnd - valueStart

			var value = delegate.saxParser(self, internedStringForValue: valueStart, count: Int(valueCount))
			if value == nil {
				value = String(bytes: UnsafeRawBufferPointer(start: valueStart, count: Int(valueCount)), encoding: .utf8)
			}

			if let value, let attributeName {
				dictionary[attributeName] = value
			}

			i += 1
			j += fieldCount
		}

		return dictionary
	}
}

private extension SAXParser {

	func charactersFound(_ xmlCharacters: XMLPointer, count: Int) {

		if storingCharacters {
			characters.append(xmlCharacters, count: count)
		}

		delegate.saxParser(self, xmlCharactersFound: xmlCharacters, count: count)
	}

	func startElement(_ name: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?, namespaceCount: Int, namespaces: UnsafeMutablePointer<XMLPointer?>?, attributeCount: Int, attributesDefaultedCount: Int, attributes: UnsafeMutablePointer<XMLPointer?>?) {

		delegate.saxParser(self, xmlStartElement: name, prefix: prefix, uri: uri, namespaceCount: namespaceCount, namespaces: namespaces, attributeCount: attributeCount, attributesDefaultedCount: attributesDefaultedCount, attributes: attributes)
	}

	func endElement(_ name: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?) {

		delegate.saxParser(self, xmlEndElement: name, prefix: prefix, uri: uri)
		endStoringCharacters()
	}
}

private func startElement(_ context: UnsafeMutableRawPointer?, name: XMLPointer?, prefix: XMLPointer?, URI: XMLPointer?, nb_namespaces: CInt, namespaces: UnsafeMutablePointer<XMLPointer?>?, nb_attributes: CInt, nb_defaulted: CInt, attributes: UnsafeMutablePointer<XMLPointer?>?) {

	guard let context, let name else {
		return
	}

	let parser = parser(from: context)
	parser.startElement(name, prefix: prefix, uri: URI, namespaceCount: Int(nb_namespaces), namespaces: namespaces, attributeCount: Int(nb_attributes), attributesDefaultedCount: Int(nb_defaulted), attributes: attributes)
}

private func endElement(_ context: UnsafeMutableRawPointer?, name: XMLPointer?, prefix: XMLPointer?, URI: XMLPointer?) {

	guard let context, let name else {
		return
	}

	let parser = parser(from: context)
	parser.endElement(name, prefix: prefix, uri: URI)
}

private func charactersFound(_ context: UnsafeMutableRawPointer?, ch: XMLPointer?, len: CInt) {

	guard let context, let ch, len > 0 else {
		return
	}

	let parser = parser(from: context)
	parser.charactersFound(ch, count: Int(len))
}

private func parser(from context: UnsafeMutableRawPointer) -> SAXParser {

	Unmanaged<SAXParser>.fromOpaque(context).takeUnretainedValue()
}

nonisolated(unsafe) private var saxHandlerStruct: xmlSAXHandler = {

	var handler = xmlSAXHandler()

	handler.characters = charactersFound
	handler.startElement = startElement
	handler.endElement = endElement

	return handler
}()


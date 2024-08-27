////
////  SAXHTMLParser.swift
////  
////
////  Created by Brent Simmons on 8/26/24.
////
//
//import Foundation
//import libxml2
//
//protocol SAXHTMLParserDelegate: AnyObject {
//
//	func saxParser(_: SAXHTMLParser, XMLStartElement localName: XMLPointer, attributes: UnsafePointer<XMLPointer?>?)
//
//	func saxParser(_: SAXHTMLParser, XMLEndElement localName: XMLPointer?)
//
//	// Length is guaranteed to be greater than 0.
//	func saxParser(_: SAXHTMLParser, XMLCharactersFound characters: XMLPointer?, length: Int)
//}
//
//final class SAXHTMLParser {
//
//	fileprivate let delegate: SAXHTMLParserDelegate
//	private var data: Data
//
//	init(delegate: SAXHTMLParserDelegate, data: Data) {
//
//		self.delegate = delegate
//		self.data = data
//	}
//
//	func parse() {
//
//		guard !data.isEmpty else {
//			return
//		}
//
//		data.withUnsafeBytes { bufferPointer in
//
//			guard let bytes = bufferPointer.bindMemory(to: xmlChar.self).baseAddress else {
//				return
//			}
//
//			let characterEncoding = xmlDetectCharEncoding(bytes, Int32(data.count))
//			let context = htmlCreatePushParserCtxt(&saxHandlerStruct, Unmanaged.passUnretained(self).toOpaque(), nil, 0, nil, characterEncoding)
//			htmlCtxtUseOptions(context, Int32(XML_PARSE_RECOVER | XML_PARSE_NONET | HTML_PARSE_COMPACT))
//
//			htmlParseChunk(context, bytes, Int32(data.count), 0)
//
//			htmlParseChunk(context, nil, 0, 1)
//			htmlFreeParserCtxt(context)
//		}
//	}
//}

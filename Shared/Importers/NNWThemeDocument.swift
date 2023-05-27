//
//  NNWThemeDocument.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 20/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

public struct NNWThemeDocument: FileDocument {
	
	public static var readableContentTypes: [UTType] {
		UTType.types(tag: "nnwtheme", tagClass: .filenameExtension, conformingTo: nil)
	}
	
	public static var writableContentTypes: [UTType] {
		UTType.types(tag: "nnwtheme", tagClass: .filenameExtension, conformingTo: nil)
	}
	
	public init(configuration: ReadConfiguration) throws {
		guard let _ = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}
		return
	}
	
	public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let wrapper = try FileWrapper(url: URL(string: "")!)
		return wrapper
	}
	
}


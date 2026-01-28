//
//  AboutContributor.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 01/01/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import Foundation

public struct AboutContributor: Identifiable, Hashable {
	public let id: UUID = UUID()

	let name: String
	let url: URL
}

public enum Contributors: CaseIterable {

	case mauriceParker
	case stuartBreckenridge
	case bradEllis
	case keilGillard
	case anhDo
	case nateWeaver
	case andrewBrehaut
	case danielJalkut
	case joeHeck
	case olofHellman
	case rizwanMohamedIbrahim
	case philViso
	case ryanDotson
	case others

	public var contributor: AboutContributor {
		switch self {
		case .mauriceParker:
			return AboutContributor(name: "Maurice Parker", url: URL(string: "https://vincode.io")!)
		case .stuartBreckenridge:
			return AboutContributor(name: "Stuart Breckenridge", url: URL(string: "https://stuartbreckenridge.net")!)
		case .bradEllis:
			return AboutContributor(name: "Brad Ellis", url: URL(string: "https://hachyderm.io/@bradellis")!)
		case .keilGillard:
			return AboutContributor(name: "Keil Gillard", url: URL(string: "https://twitter.com/kielgillard")!)
		case .anhDo:
			return AboutContributor(name: "Anh Do", url: URL(string: "https://mastodon.social/@anhdo")!)
		case .nateWeaver:
			return AboutContributor(name: "Nate Weaver", url: URL(string: "https://github.com/wevah")!)
		case .andrewBrehaut:
			return AboutContributor(name: "Andrew Brehaut", url: URL(string: "https://github.com/brehaut/")!)
		case .danielJalkut:
			return AboutContributor(name: "Daniel Jalkut", url: URL(string: "https://github.com/danielpunkass")!)
		case .joeHeck:
			return AboutContributor(name: "Joe Heck", url: URL(string: "https://rhonabwy.com/")!)
		case .olofHellman:
			return AboutContributor(name: "Olof Hellman", url: URL(string: "https://github.com/olofhellman")!)
		case .rizwanMohamedIbrahim:
			return AboutContributor(name: "Rizwan Mohamed Ibrahim", url: URL(string: "https://blog.rizwan.dev/")!)
		case .philViso:
			return AboutContributor(name: "Phil Viso", url: URL(string: "https://github.com/philviso")!)
		case .ryanDotson:
			return AboutContributor(name: "Ryan Dotson", url: URL(string: "https://github.com/nostodnayr")!)
		case .others:
			return AboutContributor(name: "and many more", url: URL(string: "https://github.com/Ranchero-Software/NetNewsWire/graphs/contributors")!)
		}
	}
}

//
//  IconImageView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 07/02/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

// SwiftUI wrapper for `IconImage`

import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

struct IconImageView: View {
	let icon: IconImage
	var size: IconSize = .small
	var cornerRadius: CGFloat = 4

	@Environment(\.colorScheme) private var colorScheme

	private var isDarkMode: Bool { colorScheme == .dark }

	private var shouldShowBackground: Bool {
		guard !icon.isBackgroundSuppressed else { return false }
		if isDarkMode {
			return icon.isDark
		} else {
			return icon.isBright
		}
	}

	private var tintColor: Color? {
		guard let cg = icon.preferredColor else { return nil }
		return Color(cgColor: cg)
	}

	var body: some View {
		ZStack {
			if shouldShowBackground {
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.fill(backgroundColor)
			}

			platformImage(for: icon)
				.resizable()
				.scaledToFit()
				.symbolRenderingMode(icon.isSymbol ? SymbolRenderingMode.palette : SymbolRenderingMode.hierarchical)
				.foregroundStyle(tintColor ?? defaultTint)
		}
		.frame(width: size.size.width, height: size.size.height)
		.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
		.accessibilityHidden(false)
	}

	private var backgroundColor: Color {
		#if os(macOS)
		let nsColor = isDarkMode ? Assets.Colors.iconDarkBackground : Assets.Colors.iconLightBackground
		return Color(nsColor: nsColor)
		#else
		return Color(Assets.Colors.iconBackground)
		#endif
	}

	// Fallback tint to something sensible if preferredColor is not set (for symbols)
	private var defaultTint: Color {
		#if os(macOS)
		return Color(nsColor: Assets.Colors.primaryAccent)
		#else
		return Color(Assets.Colors.secondaryAccent)
		#endif
	}

	private func platformImage(for icon: IconImage) -> Image {
		#if os(macOS)
		return Image(nsImage: icon.image)
		#else
		return Image(uiImage: icon.image)
		#endif
	}
}

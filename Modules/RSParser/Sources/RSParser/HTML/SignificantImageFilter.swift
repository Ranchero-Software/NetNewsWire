//
//  SignificantImageFilter.swift
//  RSParser
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation

/// Rejects images that can’t stand for an article: tracking pixels, smileys,
/// emoji, badges, share buttons, avatars, and banner-shaped strips.
/// Share buttons are recognized by their enclosing link, since the icons
/// themselves are often hosted on the blog’s own server.
///
/// Undeclared dimensions pass, since most images in feeds don’t declare them.
/// Callers that later learn the real dimensions check them with `hasSignificantDimensions`.
public enum SignificantImageFilter {

	public static let minimumDimension = 64
	public static let maximumAspectRatio = 6.0

	/// `htmlClass` is an `<img>` tag’s `class` attribute. `enclosingLinkURLString` is the `href` of the `<a>` it’s inside.
	public static func isSignificant(urlString: String, width: Int?, height: Int?, htmlClass: String? = nil, enclosingLinkURLString: String? = nil) -> Bool {
		hasSignificantDimensions(width: width, height: height) && !isBlockedURL(urlString) && !hasDecorativeClass(htmlClass) && !isSharingLink(enclosingLinkURLString)
	}

	public static func hasSignificantDimensions(width: Int?, height: Int?) -> Bool {
		if let width, width < minimumDimension {
			return false
		}
		if let height, height < minimumDimension {
			return false
		}
		if let width, let height {
			let aspectRatio = Double(max(width, height)) / Double(min(width, height))
			if aspectRatio > maximumAspectRatio {
				return false
			}
		}
		return true
	}
}

private extension SignificantImageFilter {

	typealias HostAndPathPrefix = (host: String, pathPrefix: String)

	static let decorativeClasses: Set<String> = ["emoji", "wp-smiley"]

	/// File names, without extension, of tracking pixels and placeholders on any host. Lowercase.
	static let blockedFileNames: Set<String> = ["1x1", "blank", "pixel", "spacer", "transparent"]

	/// Path components of open-tracking and click-tracking URLs on any host. Lowercase.
	static let blockedPathComponents: Set<String> = ["open", "track"]

	/// A URL ending in one of these isn’t blocked by its path components. GIF isn’t included, since it’s the usual format for tracking pixels.
	static let photoFileExtensions: Set<String> = ["avif", "heic", "jpeg", "jpg", "png", "webp"]

	/// Share buttons, badges, tracking pixels, and placeholders. Hosts include their subdomains. Path prefixes are lowercase.
	static let blockedImagePrefixes: [HostAndPathPrefix] = [
		(host: "addtoany.com", pathPrefix: "/"),
		(host: "feedburner.com", pathPrefix: "/"),
		(host: "feeds.wordpress.com", pathPrefix: "/"),
		(host: "pixel.wp.com", pathPrefix: "/"),
		(host: "s.w.org", pathPrefix: "/images/core/emoji/"),
		(host: "s0.wp.com", pathPrefix: "/i/blank.jpg"),
		(host: "stats.wordpress.com", pathPrefix: "/")
	]

	/// Share endpoints. Hosts include their subdomains. Path prefixes are lowercase.
	static let sharingLinkPrefixes: [HostAndPathPrefix] = [
		(host: "addtoany.com", pathPrefix: "/"),
		(host: "bsky.app", pathPrefix: "/intent/"),
		(host: "digg.com", pathPrefix: "/submit"),
		(host: "facebook.com", pathPrefix: "/dialog/"),
		(host: "facebook.com", pathPrefix: "/share"),
		(host: "flipboard.com", pathPrefix: "/bookmarklet"),
		(host: "getpocket.com", pathPrefix: "/save"),
		(host: "linkedin.com", pathPrefix: "/cws/share"),
		(host: "linkedin.com", pathPrefix: "/sharearticle"),
		(host: "linkedin.com", pathPrefix: "/sharing/"),
		(host: "news.ycombinator.com", pathPrefix: "/submitlink"),
		(host: "pinterest.com", pathPrefix: "/pin/create"),
		(host: "reddit.com", pathPrefix: "/submit"),
		(host: "shareaholic.com", pathPrefix: "/"),
		(host: "sharethis.com", pathPrefix: "/"),
		(host: "t.me", pathPrefix: "/share"),
		(host: "threads.net", pathPrefix: "/intent/"),
		(host: "tumblr.com", pathPrefix: "/share"),
		(host: "tumblr.com", pathPrefix: "/widgets/share"),
		(host: "twitter.com", pathPrefix: "/intent/"),
		(host: "twitter.com", pathPrefix: "/share"),
		(host: "whatsapp.com", pathPrefix: "/send"),
		(host: "x.com", pathPrefix: "/intent/"),
		(host: "x.com", pathPrefix: "/share")
	]

	static func isBlockedURL(_ urlString: String) -> Bool {
		guard let url = URL(string: urlString), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
			return true
		}
		guard let host = url.host()?.lowercased() else {
			return true
		}
		if url.pathExtension.lowercased() == "svg" {
			return true
		}
		if blockedFileNames.contains(url.deletingPathExtension().lastPathComponent.lowercased()) {
			return true
		}
		if !photoFileExtensions.contains(url.pathExtension.lowercased()), url.pathComponents.contains(where: { blockedPathComponents.contains($0.lowercased()) }) {
			return true
		}
		if matches(host: host, path: url.path().lowercased(), blockedImagePrefixes) {
			return true
		}
		return MediaRSS.isGravatar(url)
	}

	/// Includes `mailto:` links, the usual target of an email-this-article button.
	static func isSharingLink(_ urlString: String?) -> Bool {
		guard let urlString, let url = URL(string: urlString), let scheme = url.scheme?.lowercased() else {
			return false
		}
		if scheme == "mailto" {
			return true
		}
		guard let host = url.host()?.lowercased() else {
			return false
		}
		return matches(host: host, path: url.path().lowercased(), sharingLinkPrefixes)
	}

	static func matches(host: String, path: String, _ prefixes: [HostAndPathPrefix]) -> Bool {
		prefixes.contains { (host == $0.host || host.hasSuffix("." + $0.host)) && path.hasPrefix($0.pathPrefix) }
	}

	static func hasDecorativeClass(_ htmlClass: String?) -> Bool {
		guard let htmlClass else {
			return false
		}
		return htmlClass.split(whereSeparator: \.isWhitespace).contains { decorativeClasses.contains($0.lowercased()) }
	}
}

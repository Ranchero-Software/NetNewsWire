//
//  ArticleRenderer.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/8/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Articles
import Account

struct ArticleRenderer {

	private let article: Article?
	private let extractedArticle: ExtractedArticle?
	private let articleStyle: ArticleStyle
	private let title: String
	private let body: String
	private let baseURL: String?

	private init(article: Article?, extractedArticle: ExtractedArticle?, style: ArticleStyle) {
		self.article = article
		self.extractedArticle = extractedArticle
		self.articleStyle = style
		self.title = article?.title ?? ""
		if let content = extractedArticle?.content {
			self.body = content
		} else {
			self.body = article?.body ?? ""
		}
		self.baseURL = article?.baseURL?.absoluteString
	}

	// MARK: - API

	static func articleHTML(article: Article, extractedArticle: ExtractedArticle? = nil, style: ArticleStyle) -> String {
		let renderer = ArticleRenderer(article: article, extractedArticle: extractedArticle, style: style)
		return renderer.articleHTML
	}

	static func multipleSelectionHTML(style: ArticleStyle) -> String {
		let renderer = ArticleRenderer(article: nil, extractedArticle: nil, style: style)
		return renderer.multipleSelectionHTML
	}

	static func noSelectionHTML(style: ArticleStyle) -> String {
		let renderer = ArticleRenderer(article: nil, extractedArticle: nil, style: style)
		return renderer.noSelectionHTML
	}
	
	static func noContentHTML(style: ArticleStyle) -> String {
		let renderer = ArticleRenderer(article: nil, extractedArticle: nil, style: style)
		return renderer.noContentHTML
	}
}

// MARK: - Private

private extension ArticleRenderer {

	private var articleHTML: String {
		let body = RSMacroProcessor.renderedText(withTemplate: template(), substitutions: articleSubstitutions(), macroStart: "[[", macroEnd: "]]")
		return renderHTML(withBody: body)
	}

	private var multipleSelectionHTML: String {
		let body = "<h3 class='systemMessage'>Multiple selection</h3>"
		return renderHTML(withBody: body)
	}

	private var noSelectionHTML: String {
		let body = "<h3 class='systemMessage'>No selection</h3>"
		return renderHTML(withBody: body)
	}

	private var noContentHTML: String {
		return renderHTML(withBody: "")
	}

	static var faviconImgTagCache = [Feed: String]()
	static var feedIconImgTagCache = [Feed: String]()

	static var defaultStyleSheet: String = {
		let path = Bundle.main.path(forResource: "styleSheet", ofType: "css")!
		let s = try! NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
		return "\n\(s)\n"
	}()

	static let defaultTemplate: String = {
		let path = Bundle.main.path(forResource: "template", ofType: "html")!
		let s = try! NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
		return s as String
	}()

	func styleString() -> String {
		return articleStyle.css ?? ArticleRenderer.defaultStyleSheet
	}

	func template() -> String {
		return articleStyle.template ?? ArticleRenderer.defaultTemplate
	}

	func titleOrTitleLink() -> String {
		if let link = article?.preferredLink {
			return title.htmlByAddingLink(link)
		}
		return title
	}

	func articleSubstitutions() -> [String: String] {
		var d = [String: String]()

		guard let article = article else {
			assertionFailure("Article should have been set before calling this function.")
			return d
		}
		
		let title = titleOrTitleLink()
		d["title"] = title

		d["body"] = body

		d["avatars"] = ""
		var didAddAvatar = false
		if let avatarHTML = avatarImgTag() {
			d["avatars"] = "<td class=\"header rightAlign avatar\">\(avatarHTML)</td>";
			didAddAvatar = true
		}

		var feedLink = ""
		if let feedTitle = article.feed?.nameForDisplay {
			feedLink = feedTitle
			if let feedURL = article.feed?.homePageURL {
				feedLink = feedLink.htmlByAddingLink(feedURL, className: "feedLink")
			}
		}
		d["feedlink"] = feedLink

		if !didAddAvatar, let feed = article.feed {
			if let favicon = faviconImgTag(forFeed: feed) {
				d["avatars"] = "<td class=\"header rightAlign\">\(favicon)</td>";
			}
		}

		let datePublished = article.logicalDatePublished
		let longDate = dateString(datePublished, .long, .medium)
		let mediumDate = dateString(datePublished, .medium, .short)
		let shortDate = dateString(datePublished, .short, .short)

		if dateShouldBeLink() || self.title == "", let permalink = article.url {
			d["date_long"] = longDate.htmlByAddingLink(permalink)
			d["date_medium"] = mediumDate.htmlByAddingLink(permalink)
			d["date_short"] = shortDate.htmlByAddingLink(permalink)
		}
		else {
			d["date_long"] = longDate
			d["date_medium"] = mediumDate
			d["date_short"] = shortDate
		}

		d["byline"] = byline()

		return d
	}

	func dateShouldBeLink() -> Bool {
		guard let permalink = article?.url else {
			return false
		}
		guard let preferredLink = article?.preferredLink else { // Title uses preferredLink
			return false
		}
		return permalink != preferredLink // Make date a link if it’s a different link from the title’s link
	}

	func faviconImgTag(forFeed feed: Feed) -> String? {

		if let cachedImgTag = ArticleRenderer.faviconImgTagCache[feed] {
			return cachedImgTag
		}

		if let favicon = appDelegate.faviconDownloader.faviconAsAvatar(for: feed) {
			if let s = base64String(forImage: favicon) {
				var dimension = min(favicon.size.height, CGFloat(ArticleRenderer.avatarDimension)) // Assuming square images.
				dimension = max(dimension, 16) // Some favicons say they’re < 16. Force them larger.
				if dimension >= CGFloat(ArticleRenderer.avatarDimension) * 0.8 { //Close enough to scale up.
					dimension = CGFloat(ArticleRenderer.avatarDimension)
				}

				let imgTag: String
				if dimension >= CGFloat(ArticleRenderer.avatarDimension) {
					// Use rounded corners.
					imgTag = "<img src=\"data:image/tiff;base64, " + s + "\" height=\(Int(dimension)) width=\(Int(dimension)) style=\"border-radius:4px\" />"
				}
				else {
					imgTag = "<img src=\"data:image/tiff;base64, " + s + "\" height=\(Int(dimension)) width=\(Int(dimension)) />"
				}
				ArticleRenderer.faviconImgTagCache[feed] = imgTag
				return imgTag
			}
		}

		return nil
	}

	func feedIconImgTag(forFeed feed: Feed) -> String? {
		if let cachedImgTag = ArticleRenderer.feedIconImgTagCache[feed] {
			return cachedImgTag
		}

		if let icon = appDelegate.feedIconDownloader.icon(for: feed) {
			if let s = base64String(forImage: icon) {
				#if os(macOS)
				let imgTag = "<img src=\"data:image/tiff;base64, " + s + "\" height=48 width=48 />"
				#else
				let imgTag = "<img src=\"data:image/png;base64, " + s + "\" height=48 width=48 />"
				#endif
				ArticleRenderer.feedIconImgTagCache[feed] = imgTag
				return imgTag
			}
		}

		return nil
	}

	func base64String(forImage image: RSImage) -> String? {
		return image.dataRepresentation()?.base64EncodedString()
	}

	func singleArticleSpecifiedAuthor() -> Author? {
		// The author of this article, if just one.
		if let authors = article?.authors, authors.count == 1 {
			return authors.first!
		}
		return nil
	}

	func singleFeedSpecifiedAuthor() -> Author? {
		if let authors = article?.feed?.authors, authors.count == 1 {
			return authors.first!
		}
		return nil
	}

	static let avatarDimension = 48

	struct Avatar {
		let imageURL: String
		let url: String?

		func html(dimension: Int) -> String {
			let imageTag = "<img src=\"\(imageURL)\" width=\(dimension) height=\(dimension) />"
			if let url = url {
				return imageTag.htmlByAddingLink(url)
			}
			return imageTag
		}
	}

	func avatarImgTag() -> String? {
		if let author = singleArticleSpecifiedAuthor(), let imageURL = author.avatarURL {
			return Avatar(imageURL: imageURL, url: author.url).html(dimension: ArticleRenderer.avatarDimension)
		}
		if let feed = article?.feed, let imgTag = feedIconImgTag(forFeed: feed) {
			return imgTag
		}
		if let feedIconURL = article?.feed?.iconURL {
			return Avatar(imageURL: feedIconURL, url: article?.feed?.homePageURL ?? article?.feed?.url).html(dimension: ArticleRenderer.avatarDimension)
		}
		if let author = singleFeedSpecifiedAuthor(), let imageURL = author.avatarURL {
			return Avatar(imageURL: imageURL, url: author.url).html(dimension: ArticleRenderer.avatarDimension)
		}
		return nil
	}

	func byline() -> String {
		guard let authors = article?.authors ?? article?.feed?.authors, !authors.isEmpty else {
			return ""
		}

		// If the author's name is the same as the feed, then we don't want to display it.
		// This code assumes that multiple authors would never match the feed name so that
		// if there feed owner has an article co-author all authors are given the byline.
		if authors.count == 1, let author = authors.first {
			if author.name == article?.feed?.nameForDisplay {
				return ""
			}
		}
		
		var byline = ""
		var isFirstAuthor = true

		for author in authors {
			if !isFirstAuthor {
				byline += ", "
			}
			isFirstAuthor = false

			if let emailAddress = author.emailAddress, emailAddress.contains(" ") {
				byline += emailAddress // probably name plus email address
			}
			else if let name = author.name, let url = author.url {
				byline += name.htmlByAddingLink(url)
			}
			else if let name = author.name, let emailAddress = author.emailAddress {
				byline += "\(name) &lt;\(emailAddress)&lg;"
			}
			else if let name = author.name {
				byline += name
			}
			else if let emailAddress = author.emailAddress {
				byline += "&lt;\(emailAddress)&gt;" // TODO: mailto link
			}
			else if let url = author.url {
				byline += String.htmlWithLink(url)
			}
		}

		return byline
	}

	func dateString(_ date: Date, _ dateStyle: DateFormatter.Style, _ timeStyle: DateFormatter.Style) -> String {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = dateStyle
		dateFormatter.timeStyle = timeStyle
		return dateFormatter.string(from: date)
	}

	#if os(macOS)
	
	func renderHTML(withBody body: String) -> String {

		var s = "<!DOCTYPE html><html><head>\n\n"
		if let baseURL = baseURL {
			s += ("<base href=\"" + baseURL + "\"\n>")
		}
		s += title.htmlBySurroundingWithTag("title")
		s += styleString().htmlBySurroundingWithTag("style")

		s += """

		<script type="text/javascript">

		function startup() {
			var anchors = document.getElementsByTagName("a");
			for (var i = 0; i < anchors.length; i++) {
				anchors[i].addEventListener("mouseenter", function() { mouseDidEnterLink(this) });
				anchors[i].addEventListener("mouseleave", function() { mouseDidExitLink(this) });
			}
		
			document.getElementsByTagName("body")[0].querySelectorAll("style, link[rel=stylesheet]").forEach(element => element.remove());
			document.getElementsByTagName("body")[0].querySelectorAll("[style]").forEach(element => element.removeAttribute("style"));
		}

		function mouseDidEnterLink(anchor) {
			window.webkit.messageHandlers.mouseDidEnter.postMessage(anchor.href);
		}

		function mouseDidExitLink(anchor) {
			window.webkit.messageHandlers.mouseDidExit.postMessage(anchor.href);
		}

		</script>

		"""
		
		s += "\n\n</head><body onload='startup()'>\n\n"
		s += body
		s += "\n\n</body></html>"

		//print(s)

		return s
	}
	
	#else
	
	func renderHTML(withBody body: String) -> String {
		
		var s = "<!DOCTYPE html><html><head>\n"
		if let baseURL = baseURL {
			s += ("<base href=\"" + baseURL + "\"\n>")
		}
		s += "<meta name=\"viewport\" content=\"width=device-width\">\n"
		s += title.htmlBySurroundingWithTag("title")
		s += styleString().htmlBySurroundingWithTag("style")
		s += """

		<script type="text/javascript">

		function startup() {
			document.getElementsByTagName("body")[0].querySelectorAll("style, link[rel=stylesheet]").forEach(element => element.remove());
			document.getElementsByTagName("body")[0].querySelectorAll("[style]").forEach(element => element.removeAttribute("style"));
		}

		</script>

		"""
		
		s += "\n\n</head><body onload='startup()'>\n\n"
		s += body
		s += "\n\n</body></html>"
		
		return s
		
	}
	
	#endif
	
}

// MARK: - Article extension

private extension Article {

	var baseURL: URL? {
		var s = url
		if s == nil {
			s = feed?.homePageURL
		}
		if s == nil {
			s = feed?.url
		}

		guard let urlString = s else {
			return nil
		}
		var urlComponents = URLComponents(string: urlString)
		if urlComponents == nil {
			return nil
		}

		// Can’t use url-with-fragment as base URL. The webview won’t load. See scripting.com/rss.xml for example.
		urlComponents!.fragment = nil
		guard let url = urlComponents!.url, url.scheme == "http" || url.scheme == "https" else {
			return nil
		}
		return url
	}
}


//
//  ArticleRenderer.swift
//  Evergreen
//
//  Created by Brent Simmons on 9/8/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Data

var cachedStyleString = ""
var cachedTemplate = ""

class ArticleRenderer {

	let article: Article
	let articleStyle: ArticleStyle

	lazy var longDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .medium
		return dateFormatter
	}()

	lazy var mediumDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .medium
		dateFormatter.timeStyle = .short
		return dateFormatter
	}()
	
	lazy var shortDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .short
		dateFormatter.timeStyle = .short
		return dateFormatter
	}()
	
	lazy var title: String = {
		if let articleTitle = self.article.title {
			return articleTitle
		}

		return ""
		}()

	lazy var baseURL: URL? = {

		var s = self.article.url
		if s == nil {
			s = self.article.feed?.homePageURL
		}
		if s == nil {
			s = self.article.feed?.url
		}
		if s == nil {
			return nil
		}

		var urlComponents = URLComponents(string: s!)
		if urlComponents == nil {
			return nil
		}

		// Can’t use url-with-fragment as base URL. The webview won’t load. See scripting.com/rss.xml for example.
		urlComponents!.fragment = nil

		if let url = urlComponents!.url {
			if url.scheme == "http" || url.scheme == "https" {
				return url
			}
		}

		return nil
		}()

	var html: String {

		return renderedHTML()
	}

	init(article: Article, style: ArticleStyle) {

		self.article = article
		self.articleStyle = style
	}

	// MARK: Private

	private func textInsideTag(_ text: String, _ tag: String) -> String {

		return "<\(tag)>\(text)</\(tag)>"
	}

	private func styleString() -> String {

		if let s = articleStyle.css {
			return s
		}

		if cachedStyleString.isEmpty {

			let path = Bundle.main.path(forResource: "styleSheet", ofType: "css")!
			let s = try! NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
			cachedStyleString = "\n\(s)\n"
		}

		return cachedStyleString
	}

	private func template() -> String {

		if let s = articleStyle.template {
			return s
		}

		if cachedTemplate.isEmpty {
			let path = Bundle.main.path(forResource: "template", ofType: "html")!
			let s = try! NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
			cachedTemplate = s as String
		}

		return cachedTemplate
	}

	private func linkWithTextAndClass(_ text: String, _ href: String, _ className: String) -> String {
		
		return "<a class=\"\(className)\" href=\"\(href)\">\(text)</a>"
	}
	
	private func linkWithText(_ text: String, _ href: String) -> String {

		return ArticleRenderer.linkWithText(text, href)
	}

	private static func linkWithText(_ text: String, _ href: String) -> String {

		return "<a href=\"\(href)\">\(text)</a>"
	}

	private func linkWithLink(_ href: String) -> String {

		return linkWithText(href, href)
	}

	private func titleOrTitleLink() -> String {

		if let link = article.preferredLink {
			return linkWithText(title, link)
		}
		return title
	}

	private func substitutions() -> [String: String] {

		var d = [String: String]()

		let title = titleOrTitleLink()
		d["newsitem_title"] = title
		d["article_title"] = title

		let body = article.body == nil ? "" : article.body
		d["article_description"] = body
		d["newsitem_description"] = body

		d["avatars"] = ""
		if let avatars = avatarsToShow() {
			var avatarHTML = ""
			var ix = 0
			let ct = avatars.count
			for avatar in avatars {
				avatarHTML += avatar.html(dimension: 64)
				if ix < ct - 1 {
					avatarHTML += "&nbsp;"
				}
				ix += 1
			}
			if !avatarHTML.isEmpty {
				d["avatars"] = avatarHTML
			}
		}

		var feedLink = ""
		if let feedTitle = article.feed?.nameForDisplay {
			feedLink = feedTitle
			if let feedURL = article.feed?.homePageURL {
				feedLink = linkWithTextAndClass(feedTitle, feedURL, "feedLink")
			}
		}
		d["feedlink"] = feedLink
		d["feedlink_withfavicon"] = feedLink

		let longDate = longDateFormatter.string(from: article.logicalDatePublished)
		d["date_long"] = longDate

		let mediumDate = mediumDateFormatter.string(from: article.logicalDatePublished)
		d["date_medium"] = mediumDate
		
		let shortDate = shortDateFormatter.string(from: article.logicalDatePublished)
		d["date_short"] = shortDate

		d["byline"] = byline()
//		d["author_avatar"] = authorAvatar()

		return d
	}

	struct Avatar {
		let imageURL: String
		let url: String?

		func html(dimension: Int) -> String {

			let imageTag = "<img src=\"\(imageURL)\" width=\"\(dimension)\" height=\"\(dimension)\""
			if let url = url {
				return linkWithText(imageTag, url)
			}
			return imageTag
		}
	}

	private func singleArticleSpecifiedAuthor() -> Author? {

		// The author of this article, if just one.

		if let authors = article.authors, authors.count == 1 {
			return authors.first!
		}
		return nil
	}

	private func singleFeedSpecifiedAuthor() -> Author? {

		if let authors = article.feed?.authors, authors.count == 1 {
			return authors.first!
		}
		return nil
	}

	private func feedAvatar() -> Avatar? {

		guard let feedIconURL = article.feed?.iconURL else {
			return nil
		}
		return Avatar(imageURL: feedIconURL, url: article.feed?.homePageURL ?? article.feed?.url)
	}

	private func authorAvatar() -> Avatar? {

		if let author = singleArticleSpecifiedAuthor(), let imageURL = author.avatarURL {
			return Avatar(imageURL: imageURL, url: author.url)
		}
		if let author = singleFeedSpecifiedAuthor(), let imageURL = author.avatarURL {
			return Avatar(imageURL: imageURL, url: author.url)
		}
		return nil
	}

	private func avatarsToShow() -> [Avatar]? {

		var avatars = [Avatar]()
		if let avatar = feedAvatar() {
			avatars.append(avatar)
		}
		if let avatar = authorAvatar() {
			avatars.append(avatar)
		}
		return avatars.isEmpty ? nil : avatars
	}

	private func avatarToUse() -> Avatar? {

		// Use author if article specifies an author, otherwise use feed icon.
		// If no feed icon, use feed-specified author.

		if let author = singleArticleSpecifiedAuthor(), let imageURL = author.avatarURL {
			return Avatar(imageURL: imageURL, url: author.url)
		}
		if let feedIconURL = article.feed?.iconURL {
			return Avatar(imageURL: feedIconURL, url: article.feed?.homePageURL ?? article.feed?.url)
		}
		if let author = singleFeedSpecifiedAuthor(), let imageURL = author.avatarURL {
			return Avatar(imageURL: imageURL, url: author.url)
		}
		return nil
	}

//	private func authorAvatar() -> String {
//
//		guard let authors = article.authors, authors.count == 1, let author = authors.first else {
//			return ""
//		}
//		guard let avatarURL = author.avatarURL else {
//			return ""
//		}
//
//		var imageTag = "<img src=\"\(avatarURL)\" height=64 width=64 />"
//		if let authorURL = author.url {
//			imageTag = linkWithText(imageTag, authorURL)
//		}
//		return "<div id=authorAvatar>\(imageTag)</div>"
//	}

	private func byline() -> String {

		guard let authors = article.authors ?? article.feed?.authors, !authors.isEmpty else {
			return ""
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
				byline += linkWithText(name, url)
			}
			else if let name = author.name, let emailAddress = author.emailAddress {
				byline += "\(name) &lt;\(emailAddress)&lg;"
//				byline += linkWithText(name, "mailto:\(emailAddress)") //TODO
			}
			else if let name = author.name {
				byline += name
			}
			else if let emailAddress = author.emailAddress {
				byline += "&lt;\(emailAddress)&gt;" // TODO: mailto link
			}
			else if let url = author.url {
				byline += linkWithLink(url)
			}
		}


		return byline
	}

	private func renderedHTML() -> String {

		var s = "<!DOCTYPE html><html><head>\n\n"
		s += textInsideTag(title, "title")
		s += textInsideTag(styleString(), "style")

		s += """

		<script type="text/javascript">

		function startup() {
			var anchors = document.getElementsByTagName("a");
			for (var i = 0; i < anchors.length; i++) {
				anchors[i].addEventListener("mouseenter", function() { mouseDidEnterLink(this) });
				anchors[i].addEventListener("mouseleave", function() { mouseDidExitLink(this) });
			}
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


		s += RSMacroProcessor.renderedText(withTemplate: template(), substitutions: substitutions(), macroStart: "[[", macroEnd: "]]")

		s += "\n\n</body></html>"

//	print(s)

		return s

	}

}

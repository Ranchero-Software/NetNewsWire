//
//  ArticleRenderer.swift
//  Evergreen
//
//  Created by Brent Simmons on 9/8/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import DataModel

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

		var s = self.article.permalink
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

		return "<a href=\"\(href)\">\(text)</a>"
	}

	private func titleOrTitleLink() -> String {

		let link = preferredLink(for: article)
		if let link = link {
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
		
		return d
	}

	private func renderedHTML() -> String {

		var s = "<!DOCTYPE html><html><head>"
		s += textInsideTag(title, "title")
		s += textInsideTag(styleString(), "style")
		s += "</head></body>"

		s += RSMacroProcessor.renderedText(withTemplate: template(), substitutions: substitutions(), macroStart: "[[", macroEnd: "]]")

		s += "</body></html>"

//	print(s)

		return s

	}

}

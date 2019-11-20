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

	typealias Rendering = (style: String, html: String)
	typealias Page = (html: String, baseURL: URL)

	static var imageIconScheme = "nnwImageIcon"
	
	static var page: Page = {
		let pageURL = Bundle.main.url(forResource: "page", withExtension: "html")!
		let html = try! String(contentsOf: pageURL)
		let baseURL = pageURL.deletingLastPathComponent()
		return Page(html: html, baseURL: baseURL)
	}()
	
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
			self.baseURL = extractedArticle?.url
		} else {
			self.body = article?.body ?? ""
			self.baseURL = article?.baseURL?.absoluteString
		}
	}

	// MARK: - API

	static func articleHTML(article: Article, extractedArticle: ExtractedArticle? = nil, style: ArticleStyle, useImageIcon: Bool = false) -> Rendering {
		let renderer = ArticleRenderer(article: article, extractedArticle: extractedArticle, style: style)
		return (renderer.styleString(), renderer.articleHTML)
	}

	static func multipleSelectionHTML(style: ArticleStyle) -> Rendering {
		let renderer = ArticleRenderer(article: nil, extractedArticle: nil, style: style)
		return (renderer.styleString(), renderer.multipleSelectionHTML)
	}

	static func loadingHTML(style: ArticleStyle) -> Rendering {
		let renderer = ArticleRenderer(article: nil, extractedArticle: nil, style: style)
		return (renderer.styleString(), renderer.loadingHTML)
	}

	static func noSelectionHTML(style: ArticleStyle) -> Rendering {
		let renderer = ArticleRenderer(article: nil, extractedArticle: nil, style: style)
		return (renderer.styleString(), renderer.noSelectionHTML)
	}
	
	static func noContentHTML(style: ArticleStyle) -> Rendering {
		let renderer = ArticleRenderer(article: nil, extractedArticle: nil, style: style)
		return (renderer.styleString(), renderer.noContentHTML)
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

	private var loadingHTML: String {
		let body = "<h3 class='systemMessage'>Loading...</h3>"
		return renderHTML(withBody: body)
	}

	private var noSelectionHTML: String {
		let body = "<h3 class='systemMessage'>No selection</h3>"
		return renderHTML(withBody: body)
	}

	private var noContentHTML: String {
		return renderHTML(withBody: "")
	}

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
		d["avatars"] = "<td class=\"header rightAlign avatar\"><img id=\"nnwImageIcon\" src=\"\(ArticleRenderer.imageIconScheme)://\" height=48 width=48 /></td>";

		var feedLink = ""
		if let feedTitle = article.webFeed?.nameForDisplay {
			feedLink = feedTitle
			if let feedURL = article.webFeed?.homePageURL {
				feedLink = feedLink.htmlByAddingLink(feedURL, className: "feedLink")
			}
		}
		d["feedlink"] = feedLink

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

	func byline() -> String {
		guard let authors = article?.authors ?? article?.webFeed?.authors, !authors.isEmpty else {
			return ""
		}

		// If the author's name is the same as the feed, then we don't want to display it.
		// This code assumes that multiple authors would never match the feed name so that
		// if there feed owner has an article co-author all authors are given the byline.
		if authors.count == 1, let author = authors.first {
			if author.name == article?.webFeed?.nameForDisplay {
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

	func renderHTML(withBody body: String) -> String {
		var s = ""
		if let baseURL = baseURL {
			s += ("<base href=\"" + baseURL + "\"\n>")
		}
		s += title.htmlBySurroundingWithTag("title")
		
		s += body
		return s
	}

}

// MARK: - Article extension

private extension Article {

	var baseURL: URL? {
		var s = url
		if s == nil {
			s = webFeed?.homePageURL
		}
		if s == nil {
			s = webFeed?.url
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


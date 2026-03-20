//
//  AISummaryService.swift
//  NetNewsWire
//
//  Created by Codex on 2026/3/20.
//

import Foundation
import Articles
import RSCore

enum AISummaryError: LocalizedError {
	case missingConfiguration
	case invalidURL
	case noArticleContent
	case invalidResponse
	case apiError(String)

	var errorDescription: String? {
		switch self {
		case .missingConfiguration:
			return NSLocalizedString("Please configure the AI Summary URL and API Key in Settings/Preferences.", comment: "AI Summary missing configuration")
		case .invalidURL:
			return NSLocalizedString("The AI Summary URL is invalid.", comment: "AI Summary invalid URL")
		case .noArticleContent:
			return NSLocalizedString("This article does not have enough text to summarize.", comment: "AI Summary no article content")
		case .invalidResponse:
			return NSLocalizedString("The AI service returned an invalid response.", comment: "AI Summary invalid response")
		case .apiError(let message):
			let fallback = NSLocalizedString("The AI service request failed.", comment: "AI Summary API request failed")
			return message.isEmpty ? fallback : message
		}
	}
}

actor AISummaryService {
	static let shared = AISummaryService()

	private let session: URLSession
	private let model = "gpt-4o-mini"

	init(session: URLSession = .shared) {
		self.session = session
	}

	func summarize(article: Article) async throws -> String {
		let configuration = try configurationFromDefaults()
		let endpoint = try completionEndpoint(from: configuration.urlString)
		let source = articleSource(for: article)

		guard !source.isEmpty else {
			throw AISummaryError.noArticleContent
		}

		let requestBody = ChatCompletionsRequest(
			model: model,
			temperature: 0.2,
			messages: [
				.init(role: "system", content: "You summarize news articles. Be concise, factual, and avoid speculation."),
				.init(role: "user", content: "Summarize the following article. Keep the same language as the article.\n\nOutput format:\nSummary:\n<2-4 sentences>\n\nKey Points:\n- <point 1>\n- <point 2>\n- <point 3>\n\nArticle:\n\(source)")
			]
		)

		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("application/json", forHTTPHeaderField: "Accept")
		request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
		request.timeoutInterval = 60
		request.httpBody = try JSONEncoder().encode(requestBody)

		do {
			let (data, response) = try await session.data(for: request)
			guard let httpResponse = response as? HTTPURLResponse else {
				throw AISummaryError.invalidResponse
			}

			guard (200...299).contains(httpResponse.statusCode) else {
				throw AISummaryError.apiError(apiErrorMessage(from: data, statusCode: httpResponse.statusCode))
			}

			let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
			let message = decoded.firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !message.isEmpty else {
				throw AISummaryError.invalidResponse
			}

			return message
		} catch let error as AISummaryError {
			throw error
		} catch {
			throw AISummaryError.apiError(error.localizedDescription)
		}
	}
}

private extension AISummaryService {

	struct Configuration {
		let urlString: String
		let apiKey: String
	}

	func configurationFromDefaults() throws -> Configuration {
		let fallbackURL = "https://api.openai.com/v1"
		let defaults = UserDefaults.standard
		let urlString = (defaults.string(forKey: "aiSummaryAPIURL") ?? fallbackURL).trimmingCharacters(in: .whitespacesAndNewlines)
		var apiKey = (defaults.string(forKey: "aiSummaryAPIKey") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

		if apiKey.lowercased().hasPrefix("bearer ") {
			apiKey = String(apiKey.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
		}

		guard !urlString.isEmpty, !apiKey.isEmpty else {
			throw AISummaryError.missingConfiguration
		}

		return Configuration(urlString: urlString, apiKey: apiKey)
	}

	func completionEndpoint(from configuredURL: String) throws -> URL {
		guard var url = parseURL(from: configuredURL) else {
			throw AISummaryError.invalidURL
		}

		let lowercasedPath = url.path.lowercased()
		if lowercasedPath.hasSuffix("/chat/completions") {
			return url
		}

		if lowercasedPath.hasSuffix("/v1") || lowercasedPath.hasSuffix("/v1/") {
			url.appendPathComponent("chat/completions")
			return url
		}

		url.appendPathComponent("v1")
		url.appendPathComponent("chat/completions")
		return url
	}

	func parseURL(from text: String) -> URL? {
		if let url = URL(string: text), url.scheme != nil {
			return url
		}
		if !text.contains("://") {
			return URL(string: "https://\(text)")
		}
		return nil
	}

	func articleSource(for article: Article) -> String {
		var parts = [String]()

		if let title = article.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
			parts.append("Title: \(title)")
		}

		if let link = article.preferredLink, !link.isEmpty {
			parts.append("Link: \(link)")
		}

		if let summary = article.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
			parts.append("Feed Summary: \(summary)")
		}

		let bodyText = sanitizedBodyText(for: article)
		if !bodyText.isEmpty {
			parts.append("Article Content:\n\(bodyText)")
		}

		return parts.joined(separator: "\n\n")
	}

	func sanitizedBodyText(for article: Article) -> String {
		guard let body = article.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty else {
			return ""
		}
		var text = body.rsparser_stringByDecodingHTMLEntities()
		text = text.strippingHTML(maxCharacters: 8_000)
		text = text.trimmingCharacters(in: .whitespacesAndNewlines)
		if text == "Comments" {
			return ""
		}
		return text
	}

	func apiErrorMessage(from data: Data, statusCode: Int) -> String {
		if let decoded = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
		   let message = decoded.error.message?.trimmingCharacters(in: .whitespacesAndNewlines),
		   !message.isEmpty {
			return message
		}

		if let text = String(data: data, encoding: .utf8) {
			let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
			if !trimmed.isEmpty {
				return trimmed.count > 300 ? String(trimmed.prefix(300)) : trimmed
			}
		}

		let format = NSLocalizedString("AI service error (HTTP %d).", comment: "AI summary HTTP status fallback")
		return String(format: format, statusCode)
	}
}

private struct ChatCompletionsRequest: Encodable {
	let model: String
	let temperature: Double
	let messages: [Message]

	struct Message: Encodable {
		let role: String
		let content: String
	}
}

private struct ChatCompletionsResponse: Decodable {
	let choices: [Choice]

	var firstMessage: String {
		for choice in choices {
			if let messageContent = choice.message?.contentText, !messageContent.isEmpty {
				return messageContent
			}
			if let text = choice.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
				return text
			}
		}
		return ""
	}

	struct Choice: Decodable {
		let message: Message?
		let text: String?
	}

	struct Message: Decodable {
		let contentText: String

		enum CodingKeys: String, CodingKey {
			case content
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			if let stringContent = try? container.decode(String.self, forKey: .content) {
				contentText = stringContent
				return
			}

			if let partContent = try? container.decode([MessagePart].self, forKey: .content) {
				let joined = partContent.compactMap { $0.text }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
				contentText = joined
				return
			}

			contentText = ""
		}
	}

	struct MessagePart: Decodable {
		let text: String?
	}
}

private struct APIErrorResponse: Decodable {
	let error: APIError

	struct APIError: Decodable {
		let message: String?
	}
}

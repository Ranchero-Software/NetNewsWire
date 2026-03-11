//
//  ActivityItemSourceTests.swift
//  NetNewsWire-iOSTests
//
//  Created by Codex on 3/11/26.
//

import UIKit
import XCTest
@testable import NetNewsWire

@MainActor final class ActivityItemSourceTests: XCTestCase {

	func testTitleItemSourceReturnsTitleForSupportedActivity() {
		let source = TitleActivityItemSource(title: "Test Title")

		let item = source.activityViewController(makeActivityViewController(), itemForActivityType: UIActivity.ActivityType(rawValue: "com.buffer.buffer.Buffer"))

		XCTAssertEqual(item as? String, "Test Title")
	}

	func testTitleItemSourceReturnsNullForUnsupportedActivity() {
		let source = TitleActivityItemSource(title: "Test Title")

		let item = source.activityViewController(makeActivityViewController(), itemForActivityType: .postToFacebook)

		XCTAssertTrue(item is NSNull)
	}

	func testTitleItemSourceReturnsNullWhenTitleIsMissing() {
		let source = TitleActivityItemSource(title: nil)

		let item = source.activityViewController(makeActivityViewController(), itemForActivityType: UIActivity.ActivityType(rawValue: "com.buffer.buffer.Buffer"))

		XCTAssertTrue(item is NSNull)
	}

	func testArticleActivityItemSourceReturnsURLAndSubject() {
		let url = URL(string: "https://netnewswire.com/story")!
		let source = ArticleActivityItemSource(url: url, subject: "Subject")
		let activityViewController = makeActivityViewController()

		XCTAssertEqual(source.activityViewControllerPlaceholderItem(activityViewController) as? URL, url)
		XCTAssertEqual(source.activityViewController(activityViewController, itemForActivityType: nil) as? URL, url)
		XCTAssertEqual(source.activityViewController(activityViewController, subjectForActivityType: nil), "Subject")
	}

	func testArticleActivityItemSourceFallsBackToEmptySubject() {
		let source = ArticleActivityItemSource(url: URL(string: "https://netnewswire.com/story")!, subject: nil)

		XCTAssertEqual(source.activityViewController(makeActivityViewController(), subjectForActivityType: nil), "")
	}

	private func makeActivityViewController() -> UIActivityViewController {
		UIActivityViewController(activityItems: [URL(string: "https://netnewswire.com")!], applicationActivities: nil)
	}

}

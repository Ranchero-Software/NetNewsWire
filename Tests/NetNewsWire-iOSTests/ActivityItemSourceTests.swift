//
//  ActivityItemSourceTests.swift
//  NetNewsWire-iOSTests
//
//  Created by Rizwan Mohamed Ibrahim on 3/11/26.
//

import Testing
import UIKit
@testable import NetNewsWire

@MainActor @Suite struct ActivityItemSourceTests {

	@Test("Title is returned for each supported activity type",
	      arguments: [
		      "com.omnigroup.OmniFocus3.iOS.QuickEntry",
		      "com.culturedcode.ThingsiPhone.ShareExtension",
		      "com.buffer.buffer.Buffer"
	      ])
	func titleItemSourceReturnsTitleForSupportedActivity(rawValue: String) {
		let source = TitleActivityItemSource(title: "Test Title")

		let item = source.activityViewController(makeActivityViewController(), itemForActivityType: UIActivity.ActivityType(rawValue: rawValue))

		#expect(item as? String == "Test Title")
	}

	@Test func titleItemSourceReturnsNullForUnsupportedActivity() {
		let source = TitleActivityItemSource(title: "Test Title")

		let item = source.activityViewController(makeActivityViewController(), itemForActivityType: .postToFacebook)

		#expect(item is NSNull)
	}

	@Test func titleItemSourceReturnsNullWhenTitleIsMissing() {
		let source = TitleActivityItemSource(title: nil)

		let item = source.activityViewController(makeActivityViewController(), itemForActivityType: UIActivity.ActivityType(rawValue: "com.buffer.buffer.Buffer"))

		#expect(item is NSNull)
	}

	@Test func articleActivityItemSourceFallsBackToEmptySubject() {
		let source = ArticleActivityItemSource(url: URL(string: "https://netnewswire.com/story")!, subject: nil)

		#expect(source.activityViewController(makeActivityViewController(), subjectForActivityType: nil) == "")
	}

	private func makeActivityViewController() -> UIActivityViewController {
		UIActivityViewController(activityItems: [URL(string: "https://netnewswire.com")!], applicationActivities: nil)
	}
}

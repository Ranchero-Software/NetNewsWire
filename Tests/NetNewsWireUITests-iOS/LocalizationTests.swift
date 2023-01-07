//
//  LocalizationTests.swift
//  NetNewsWireTests
//
//  Created by Stuart Breckenridge on 04/01/2023.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import XCTest

final class LocalizationTests_iOSTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAppRunThrough() throws {
        // UI tests must launch the application that they test.
		let app = XCUIApplication()
		app.launch()
		
		_ = addUIInterruptionMonitor(withDescription: "Handle Notifications Alert") { element in
			if element.buttons["Allow"].exists {
				element.buttons["Allow"].tap()
				return true
			}
			return false
		}
		
		app.toolbars["Toolbar"].buttons["Settings"].tap()
		
		let collectionViewsQuery = app.collectionViews
		collectionViewsQuery/*@START_MENU_TOKEN@*/.buttons["Manage Accounts"]/*[[".cells.buttons[\"Manage Accounts\"]",".buttons[\"Manage Accounts\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
		app.navigationBars["Manage Accounts"]/*@START_MENU_TOKEN@*/.buttons["Add"]/*[[".otherElements[\"Add\"].buttons[\"Add\"]",".buttons[\"Add\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
		app.navigationBars["Add Account"]/*@START_MENU_TOKEN@*/.buttons["Cancel"]/*[[".otherElements[\"Cancel\"].buttons[\"Cancel\"]",".buttons[\"Cancel\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
		app.navigationBars["Manage Accounts"].buttons["Settings"].tap()
		collectionViewsQuery/*@START_MENU_TOKEN@*/.buttons["Manage Extensions"]/*[[".cells.buttons[\"Manage Extensions\"]",".buttons[\"Manage Extensions\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
		app.navigationBars["Manage Extensions"]/*@START_MENU_TOKEN@*/.buttons["Add"]/*[[".otherElements[\"Add\"].buttons[\"Add\"]",".buttons[\"Add\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
		app.navigationBars["Add Extensions"]/*@START_MENU_TOKEN@*/.buttons["Cancel"]/*[[".otherElements[\"Cancel\"].buttons[\"Cancel\"]",".buttons[\"Cancel\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
		app.navigationBars["Manage Extensions"].buttons["Settings"].tap()
		collectionViewsQuery/*@START_MENU_TOKEN@*/.buttons["Import Subscriptions"]/*[[".cells.buttons[\"Import Subscriptions\"]",".buttons[\"Import Subscriptions\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
		app/*@START_MENU_TOKEN@*/.scrollViews/*[[".otherElements[\"Choose an account to receive the imported feeds and folders\"].scrollViews",".scrollViews"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.otherElements.buttons["Cancel"].tap()
		collectionViewsQuery/*@START_MENU_TOKEN@*/.buttons["Export Subscriptions"]/*[[".cells.buttons[\"Export Subscriptions\"]",".buttons[\"Export Subscriptions\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
		app/*@START_MENU_TOKEN@*/.scrollViews/*[[".otherElements[\"Choose an account with the subscriptions to export\"].scrollViews",".scrollViews"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.otherElements.buttons["Cancel"].tap()
		let displayBehaviorsButton = collectionViewsQuery.buttons["button.title.display-and-behaviors"]
		displayBehaviorsButton.tap()
		app.navigationBars.buttons["Settings"].tap()
		collectionViewsQuery/*@START_MENU_TOKEN@*/.buttons["New Article Notifications"]/*[[".cells.buttons[\"New Article Notifications\"]",".buttons[\"New Article Notifications\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
		app.navigationBars["New Article Notifications"].buttons["Settings"].tap()
		displayBehaviorsButton.swipeUp()
		collectionViewsQuery/*@START_MENU_TOKEN@*/.buttons["About"]/*[[".cells.buttons[\"About\"]",".buttons[\"About\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
		app.navigationBars["About"].buttons["Settings"].tap()
    }
	
	private func addScreenShot(_ name: String, app: XCUIApplication) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}

}

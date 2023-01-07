//
//  NetNewsWireUITests_iOSLaunchTests.swift
//  NetNewsWireUITests-iOS
//
//  Created by Stuart Breckenridge on 04/01/2023.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import XCTest

final class NetNewsWireUITests_iOSLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

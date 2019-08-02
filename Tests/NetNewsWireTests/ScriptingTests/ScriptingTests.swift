//
//  ScriptingTests.swift
//  NetNewsWireTests
//
//  Created by Olof Hellman on 1/7/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import XCTest

class ScriptingTests: AppleScriptXCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    
    /*
        @function testGenericScript
        @brief  An example of how a script can be run as part of an XCTest
                the applescript returns 
                     {test_result:true, script_result:"Geoducks!"}
                doIndividualScript() verifies the test_result portion
                this code verifies the script_result portion
    */
    func testGenericScript() {
        let scriptResult = doIndividualScript(filename: "testGenericScript")
        XCTAssert( scriptResult?.stringValue == "Geoducks!")
    }
    
    func testGetUrlScript() {
        _ = doIndividualScript(filename: "testGetURL")
    }
    
    func testNameAndUrlOfEveryFeedScript() {
        _ = doIndividualScript(filename: "testNameAndUrlOfEveryFeed")
    }
    
    func testNameOfEveryFolderScript() {
        _ = doIndividualScript(filename: "testNameOfEveryFolder")
    }
    
    func testNameOfAuthorsScript() {
        _ = doIndividualScript(filename: "testNameOfAuthors")
    }
    
    func testFeedExists() {
        _ = doIndividualScript(filename: "testFeedExists")
    }
    
    func testFeedOPML() {
        _ = doIndividualScript(filename: "testFeedOPML")
    }

//    func testTitleOfArticlesWhoseScript() {
//        _ = doIndividualScript(filename: "testTitleOfArticlesWhose")
//    }
//
//    func testIterativeCreateAndDeleteScript() {
//        _ = doIndividualScriptWithExpectation(filename: "testIterativeCreateAndDeleteFeed")
//    }

    func doIndividualScriptWithExpectation(filename:String) {
        let queue = DispatchQueue(label:"testQueue")
        let scriptExpectation = self.expectation(description: filename+"expectation")
        queue.async {
             _ = self.doIndividualScript(filename:filename)
             scriptExpectation.fulfill()
        }
        self.wait(for:[scriptExpectation], timeout:60)
    }

/*
    @function testCurrentArticleScripts
    @brief    the pices of the test are broken up into smaller pieces because of the
              way events are delivered to the app -- I tried one single script with all the
              actions and the keystrokes aren't delivered to the app right away, so the ui
              isn't updated in time for 'current article' to be set.  But, breaking them up
              in this way seems to work.
              
              July 30, 2019:  There's an issue where in order for a script to send keystrokes,
			  The app has to be allowed to interact with the SystemEvents.app in
			  System Preferences -> Security & Privacy -> Privacy -> Accessibility
			  and this premission needs to be renewed every time the app is recompiled unless
			  the app is codesigned.  Until we figure out how to get around this limitation,
			  this test is disabled.
*/
    func disabledTestCurrentArticleScripts() {
        
        doIndividualScriptWithExpectation(filename: "uiScriptingTestSetup")
        doIndividualScriptWithExpectation(filename: "establishMainWindowStartingState")
        doIndividualScriptWithExpectation(filename: "selectAFeed")
        doIndividualScriptWithExpectation(filename: "testCurrentArticleIsNil")
        doIndividualScriptWithExpectation(filename: "selectAnArticle")
        doIndividualScriptWithExpectation(filename: "testURLsOfCurrentArticle")
    }
}



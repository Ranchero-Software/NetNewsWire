//
//  ScriptingTests.swift
//  NetNewsWireTests
//
//  Created by Olof Hellman on 1/7/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import XCTest

final class ScriptingTests: AppleScriptXCTestCase {

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
    
    func doIndividualScriptWithExpectation(filename:String) {
        let scriptExpectation = self.expectation(description: filename+"expectation")
		DispatchQueue.main.async {
             _ = self.doIndividualScript(filename:filename)
             scriptExpectation.fulfill()
        }
        self.wait(for:[scriptExpectation], timeout:60)
    }
}

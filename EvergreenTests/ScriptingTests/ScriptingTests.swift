//
//  ScriptingTests.swift
//  EvergreenTests
//
//  Created by Olof Hellman on 1/7/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import XCTest

class ScriptingTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    /*
        @function doIndividualScript
        @param filename -- name of a .applescript (sans extention) in the test bundle's 
                           Resources/TestScripts directory
        @brief  given a file, loads the script and runs it.  Expects a result from running
                the script of the form
                     {test_result:true, script_result:<anything>}
                if the test_result is false or is missing, the test fails
        @return  the value of script_result, if any
    */
    func doIndividualScript(filename:String) -> NSAppleEventDescriptor? {
        var errorDict: NSDictionary? = nil
        let testBundle = Bundle(for: type(of: self))
        let url = testBundle.url(forResource:filename, withExtension:"applescript", subdirectory:"TestScripts")
        guard let testScriptUrl = url  else {
            XCTFail("Failed Getting script URL")
            return nil
        }
        
        guard let testScript = NSAppleScript(contentsOf: testScriptUrl, error: &errorDict) else {
            XCTFail("Failed initializing NSAppleScript")
            print ("error is \(String(describing: errorDict))")
            return nil
        }
        
        let scriptResult = testScript.executeAndReturnError(&errorDict)
        if (errorDict != nil) {
            XCTFail("Failed executing script")
            print ("error is \(String(describing: errorDict))")
            return nil
        }
        
        let usrfDictionary = scriptResult.usrfDictionary()
        guard let testResult = usrfDictionary["test_result"] else {
            XCTFail("test script didn't return test result in usrf")
            return nil
        }
        
        XCTAssert(testResult.booleanValue == true, "test_result should be true")
        
        return usrfDictionary["script_result"]
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

}

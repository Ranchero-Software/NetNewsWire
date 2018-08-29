
-- NetNewsWire scripting unit tests expect a dictionary to be returned from a script
-- containing either 
--      {test_result:true}  
-- to indicate success or 
--      {test_result:false}
-- to indicate failure
-- Data can be passed back to unit test code by including a script_result field
-- for example this script returns "Geoducks!" as the result
-- this can be used as part of XCTest verification
-- see the testGenericScript() function in the ScriptingTests XCTestCase

return {test_result:true, script_result:"Geoducks!"}

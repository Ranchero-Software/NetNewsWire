//
//  NSAppleEventDescriptor+UserRecordFields.swift
//  NetNewsWireTests
//
//  Created by Olof Hellman on 1/7/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Foundation

/*
   @function usrfDictionary()
   @brief    When an apple event record contains key-value pairs for which the keys are 
   			 not associated with FourCharCode keys, the keys and values appear in a 
             "user record fields" AEList, in which the odd items are the keys and the 
             even items are the values.  This function unpacks user record fields and 
             returns an analogous Swift dictionary
*/
extension NSAppleEventDescriptor {
    public func usrfDictionary() -> [String:NSAppleEventDescriptor] {
        guard self.isRecordDescriptor else {
            print ("error: usrfDictionary() expected input to be a record")
            return [:]
        }
		guard let usrfList = self.forKeyword("usrf".fourCharCode) else {
            print ("error: usrfDictionary() couldn't find usrf")
            return [:]
        }
        let listCount = usrfList.numberOfItems
        guard (listCount%2 == 0) else {
            print ("error: usrfDictionary() expected even number of items in usrf")
            return [:]
        }
        var usrfDictionary:[String:NSAppleEventDescriptor] = [:]
        var processedItems = 0
        while (processedItems < listCount) {
            processedItems = processedItems + 2
            guard let nthlabel = usrfList.atIndex(processedItems-1) else {
                print("usrfDictionary() couldn't get item \(processedItems+1) in usrf list")
                continue
            }
            guard let nthvalue = usrfList.atIndex(processedItems) else {
                print("usrfDictionary() couldn't get item \(processedItems+2) in usrf list")
                continue
            }
            guard let nthLabelString = nthlabel.stringValue else {
                print("usrfDictionary() expected label to be a String")
                continue
            }
            usrfDictionary[nthLabelString] = nthvalue
        }
        return usrfDictionary;
    }
}

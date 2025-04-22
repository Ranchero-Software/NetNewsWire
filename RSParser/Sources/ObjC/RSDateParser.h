//
//  RSDateParser.h
//  RSParser
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


// Common web dates -- RFC 822 and 8601 -- are handled here: the formats you find in JSON and XML feeds.
// These may return nil. They may also return garbage, given bad input.

NSDate *RSDateWithString(NSString *dateString);

// If you're using a SAX parser, you have the bytes and don't need to convert to a string first.
// It's faster and uses less memory.
// (Assumes bytes are UTF-8 or ASCII. If you're using the libxml SAX parser, this will work.)

NSDate *RSDateWithBytes(const char *bytes, NSUInteger numberOfBytes);


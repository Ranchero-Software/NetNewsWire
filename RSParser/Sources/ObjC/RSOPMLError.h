//
//  RSOPMLError.h
//  RSParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

extern NSString *RSOPMLErrorDomain;


typedef NS_ENUM(NSInteger, RSOPMLErrorCode) {
	RSOPMLErrorCodeDataIsWrongFormat = 1024
};


NSError *RSOPMLWrongFormatError(NSString *fileName);

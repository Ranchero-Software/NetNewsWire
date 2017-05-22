//
//  RSXMLError.h
//  RSXML
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

extern NSString *RSXMLErrorDomain;


typedef NS_ENUM(NSInteger, RSXMLErrorCode) {
	RSXMLErrorCodeDataIsWrongFormat = 1024
};


NSError *RSOPMLWrongFormatError(NSString *fileName);

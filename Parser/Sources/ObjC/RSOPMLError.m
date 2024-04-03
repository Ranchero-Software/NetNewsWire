//
//  RSOPMLError.m
//  RSParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RSOPMLError.h"

NSString *RSOPMLErrorDomain = @"com.ranchero.OPML";

NSError *RSOPMLWrongFormatError(NSString *fileName) {

	NSString *localizedDescriptionFormatString = NSLocalizedString(@"The file ‘%@’ can’t be parsed because it’s not an OPML file.", @"OPML wrong format");
	NSString *localizedDescription = [NSString stringWithFormat:localizedDescriptionFormatString, fileName];

	NSString *localizedFailureString = NSLocalizedString(@"The file is not an OPML file.", @"OPML wrong format");
	NSDictionary *userInfo = @{NSLocalizedDescriptionKey: localizedDescription, NSLocalizedFailureReasonErrorKey: localizedFailureString};

	return [[NSError alloc] initWithDomain:RSOPMLErrorDomain code:RSOPMLErrorCodeDataIsWrongFormat userInfo:userInfo];
}

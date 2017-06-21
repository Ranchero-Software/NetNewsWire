//
//  RSXMLData.m
//  RSXML
//
//  Created by Brent Simmons on 8/24/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSXMLData.h"

@implementation RSXMLData


- (instancetype)initWithData:(NSData *)data urlString:(NSString *)urlString {
	
	self = [super init];
	if (!self) {
		return nil;
	}
	
	_data = data;
	_urlString = urlString;
	
	return self;
}


@end

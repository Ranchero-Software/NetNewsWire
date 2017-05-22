//
//  RSOPMLParser.h
//  RSXML
//
//  Created by Brent Simmons on 7/12/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


@class RSXMLData;
@class RSOPMLDocument;


typedef void (^RSParsedOPMLBlock)(RSOPMLDocument *OPMLDocument, NSError *error);

void RSParseOPML(RSXMLData *xmlData, RSParsedOPMLBlock callback); //async; calls back on main thread.


@interface RSOPMLParser: NSObject

- (instancetype)initWithXMLData:(RSXMLData *)xmlData;

@property (nonatomic, readonly) RSOPMLDocument *OPMLDocument;
@property (nonatomic, readonly) NSError *error;

@end


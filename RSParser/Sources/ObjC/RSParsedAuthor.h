//
//  RSParsedAuthor.h
//  RSParserTests
//
//  Created by Brent Simmons on 12/19/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

@interface RSParsedAuthor : NSObject

@property (nonatomic, nullable) NSString *name;
@property (nonatomic, nullable) NSString *emailAddress;
@property (nonatomic, nullable) NSString *url;

+ (instancetype _Nonnull )authorWithSingleString:(NSString *_Nonnull)s; // Don’t know which property it is. Guess based on contents of the string. Common with RSS.

@end

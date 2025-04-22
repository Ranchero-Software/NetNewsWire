//
//  RSParsedEnclosure.h
//  RSParser
//
//  Created by Brent Simmons on 12/18/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface RSParsedEnclosure : NSObject

@property (nonatomic) NSString *url;
@property (nonatomic) NSInteger length;
@property (nonatomic, nullable) NSString *mimeType;
@property (nonatomic, nullable) NSString *title;

@end

NS_ASSUME_NONNULL_END

//
//  RSXMLData.h
//  RSXML
//
//  Created by Brent Simmons on 8/24/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface RSXMLData : NSObject

- (instancetype)initWithData:(NSData *)data urlString:(NSString *)urlString;

@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) NSString *urlString;

@end

NS_ASSUME_NONNULL_END

//
//  RSOPMLDocument.h
//  RSParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

#import "RSOPMLItem.h"




@interface RSOPMLDocument : RSOPMLItem

@property (nonatomic) NSString *title;
@property (nonatomic) NSString *url;

@end

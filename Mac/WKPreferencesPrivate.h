//
//  WKPreferencesPrivate.h
//  NetNewsWire
//
//  Created by Nate Weaver on 2019-09-17.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

#import <WebKit/WebKit.h>

@interface WKPreferences (Private)

@property (nonatomic, setter=_setDeveloperExtrasEnabled:) BOOL _developerExtrasEnabled API_AVAILABLE(macos(10.11), ios(9.0));

@end

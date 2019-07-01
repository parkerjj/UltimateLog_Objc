//
//  UltimateLog_ObjC.h
//  UltimateLog-ObjC
//
//  Created by Peigen.Liu on 6/26/19.
//  Copyright © 2019 Peigen.Liu. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for UltimateLog_ObjC.
FOUNDATION_EXPORT double UltimateLog_ObjCVersionNumber;

//! Project version string for UltimateLog_ObjC.
FOUNDATION_EXPORT const unsigned char UltimateLog_ObjCVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <UltimateLog_ObjC/PublicHeader.h>



#import <CommonCrypto/CommonHMAC.h>
#import "UltimateLog.h"



#define LogFormat( s, ... )     [NSString stringWithFormat:(s), ##__VA_ARGS__]



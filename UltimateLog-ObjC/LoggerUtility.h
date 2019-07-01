//
//  LoggerUtility.h
//  UltimateLog-ObjC
//
//  Created by Peigen.Liu on 6/26/19.
//  Copyright © 2019 Peigen.Liu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LoggerUtility : NSObject



+ (void)printInitInfo;


+ (NSString *)genRandStringLength:(int)len;

@end

NS_ASSUME_NONNULL_END

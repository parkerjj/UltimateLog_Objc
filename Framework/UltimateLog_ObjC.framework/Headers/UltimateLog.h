//
//  UltimateLog.h
//  UltimateLog-ObjC
//
//  Created by Peigen.Liu on 6/26/19.
//  Copyright © 2019 Peigen.Liu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


typedef enum : NSUInteger {
    ULogFilterLevelVerbose = 0,
    ULogFilterLevelDebug,
    ULogFilterLevelInfo,
    ULogFilterLevelWarn,
    ULogFilterLevelError,
    ULogFilterLevelFatal
} ULogFilterLevel;

@interface UltimateLog : NSObject


/**
 Get the Singleton sharedInstance
 */
+ (UltimateLog*)sharedInstance;



/// Initial and setup the UltimateLog at very beginning.
/// @param prefix Your product's prefix.
/// @param cFilter Console Filter. Any message's level if less then this will not show in console.
/// @param lFilter Log Filter.  Message's level less then this will not log into the file.
/// @param encryptSeed Encrypted Seed.  It can be nil to disable the encrypt function.
+ (void)setupWithPrefix:(NSString*)prefix withConsoleFilter:(ULogFilterLevel)cFilter  withLogFilter:(ULogFilterLevel)lFilter withEncryptSeed:(NSString *)encryptSeed;





/// Zip the log files and return Zip path
+ (NSString*)zipLog;



/// Log with level
/// @param tag Tag
/// @param msg Message
+ (void)vWithTag:(NSString* __nullable)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3);
+ (void)dWithTag:(NSString* __nullable)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3);
+ (void)iWithTag:(NSString* __nullable)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3);
+ (void)wWithTag:(NSString* __nullable)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3);
+ (void)eWithTag:(NSString* __nullable)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3);
+ (void)fWithTag:(NSString* __nullable)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3);


@end

NS_ASSUME_NONNULL_END

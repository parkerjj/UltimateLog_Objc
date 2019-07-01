//
//  UltimateLog.m
//  UltimateLog-ObjC
//
//  Created by Peigen.Liu on 6/26/19.
//  Copyright © 2019 Peigen.Liu. All rights reserved.
//

#import "UltimateLog.h"
#import "MarsWapper.h"
#import "LoggerUtility.h"
#import "NSString+CommonCrypto.h"
#import "NSData+CommonCrypto.h"
#import "AESCrypt.h"
#import "ULZipZap.h"


@interface UltimateLog(){
    
}

@property (nonatomic, assign)   ULogFilterLevel consoleFilter;
@property (nonatomic, assign)   ULogFilterLevel logFilter;
@property (nonatomic, strong)   MarsWapper *mars;
@property (nonatomic, copy)     NSString *logPath;
@property (nonatomic, copy)     NSData   *encryptKey;
@property (nonatomic, assign)   NSUInteger logCount;

@end

@implementation UltimateLog
static UltimateLog *sharedInstance;



+ (void)initialize{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[UltimateLog alloc] init];
    });
}

+ (UltimateLog*)sharedInstance{
    return sharedInstance;
}

- (instancetype)init{
    self = [super init];
    if (self){
        self.logCount = 0;
        self.mars = [[MarsWapper alloc] init];
        self.logPath = [NSString stringWithFormat:@"%@/UltimateLog/", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]];
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.logPath]){
            [[NSFileManager defaultManager] createDirectoryAtPath:self.logPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        self.consoleFilter = ULogFilterLevelFatal;
        self.logFilter = ULogFilterLevelDebug;
    }
    return self;
}


+ (void)setupWithPrefix:(NSString*)prefix withConsoleFilter:(ULogFilterLevel)cFilter withLogFilter:(ULogFilterLevel)lFilter withEncryptSeed:(NSString*)encryptSeed{
    
    if (encryptSeed != nil && encryptSeed.length > 0){
        [[UltimateLog sharedInstance] plantEncryptSeed:encryptSeed];
    }
    
    [[UltimateLog sharedInstance] setConsoleFilter:cFilter];
    [[UltimateLog sharedInstance] setLogFilter:lFilter];
    
    [[UltimateLog sharedInstance].mars initXloggerFilterLevel:(int)lFilter path:sharedInstance.logPath prefix:[prefix cStringUsingEncoding:NSUTF8StringEncoding]];
    
    // Print some init info.
    [LoggerUtility printInitInfo];
    
}


- (void)plantEncryptSeed:(NSString*)seed{
    
    if (seed == nil || seed.length == 0){
        return;
    }
    
    NSData *password = [[[[[NSString stringWithFormat:@"%@%@",[seed SHA256Hex],seed] uppercaseString] dataUsingEncoding:NSUTF8StringEncoding] SHA256Hash] copy];
    NSString *originKey = [seed SHA256Hex];
    NSString *encryptKey = [AESCrypt encrypt:originKey passwordDataKey:password];
    if (encryptKey != nil){
        [[UltimateLog sharedInstance] setEncryptKey:[[encryptKey dataUsingEncoding:NSUTF8StringEncoding] SHA256Hash]];
    }
    
    
}


- (NSString*)encrypt:(NSString*)originString {
    if (self.encryptKey == nil)
        return originString;
    
    if (self.encryptKey != nil && self.encryptKey.length == 32){
        NSString *encryptedString = [AESCrypt encrypt:originString passwordDataKey:self.encryptKey];
        return [NSString stringWithFormat:@"[[[%@]]]",encryptedString];
    }
    
    return nil;
}



- (void)logsCountPlus{
    self.logCount++;
    
    if (self.logCount > 30){
        [self.mars flush];
        self.logCount = 0;
    }
}


- (void)printLogWithLevel:(ULogFilterLevel)level withTag:(NSString*)tag withMessage:(NSString *)msg{
    
    if (self.consoleFilter > level){
        return;
    }
    
    NSString *levelStr = @"";
    
    switch (level){
        case ULogFilterLevelVerbose:
            levelStr = @"[V]";
            break;
            
        case ULogFilterLevelDebug:
            levelStr = @"[D]";
            break;
            
        case ULogFilterLevelInfo:
            levelStr = @"[I]";
            break;
            
        case ULogFilterLevelWarn:
            levelStr = @"⚠️[W]";
            break;
            
        case ULogFilterLevelError:
            levelStr = @"❌[E]";
            break;
        default:{
            
        }
    }
    
    printf("%s\n", [[NSString stringWithFormat:@"%@ [%@]   %@",levelStr, tag, msg] cStringUsingEncoding:NSUTF8StringEncoding]);
    
    
}

#pragma mark - Zip

+ (NSString*)zipLog{
    NSString *tempDir = NSTemporaryDirectory();
    
    NSURL *sourceURL = [NSURL fileURLWithPath:[sharedInstance logPath]];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy_MM_dd_HH:mm:ss";
    
    NSString *destPath = [NSString stringWithFormat:@"%@%@_%@.zip",tempDir, [formatter stringFromDate:[NSDate date]],[LoggerUtility genRandStringLength:8]];
    NSURL *destUrl = [NSURL fileURLWithPath:destPath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]){
        [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
    }
    
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSError *error = nil;
    ULZZArchive *archive = [[ULZZArchive alloc] initWithURL:destUrl options:@{ULZZOpenOptionsCreateIfMissingKey : @YES} error:&error];
    [archive updateEntries:@[
                             [ULZZArchiveEntry archiveEntryWithDirectoryName:sourceURL.path]
                             ] error:&error];
    
    if (error == nil)
        return destPath;
    
    return nil;
}



#pragma mark - Log Imp

+ (void)vWithTag:(NSString*)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3){
    [sharedInstance logsCountPlus];
    
    if (tag == nil){
        tag = @"ULog";
    }
    
    va_list args;
    va_start(args, msg);
    NSString *str = [[NSString alloc] initWithFormat:msg arguments:args];
    va_end(args);

    
    [sharedInstance printLogWithLevel:ULogFilterLevelVerbose withTag:tag withMessage:str];
    
    NSString *encryptedString = [sharedInstance encrypt:msg];
    if (encryptedString != nil && encryptedString.length > 0){
        [sharedInstance.mars log:(int)ULogFilterLevelVerbose tag:[tag cStringUsingEncoding:NSUTF8StringEncoding] content:encryptedString];
    }
    
}

+ (void)dWithTag:(NSString*)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3){
    [sharedInstance logsCountPlus];
    
    if (tag == nil){
        tag = @"ULog";
    }
    
    va_list args;
    va_start(args, msg);
    NSString *str = [[NSString alloc] initWithFormat:msg arguments:args];
    va_end(args);

    [sharedInstance printLogWithLevel:ULogFilterLevelDebug withTag:tag withMessage:str];
    
    NSString *encryptedString = [sharedInstance encrypt:msg];
    if (encryptedString != nil && encryptedString.length > 0){
        [sharedInstance.mars log:(int)ULogFilterLevelDebug tag:[tag cStringUsingEncoding:NSUTF8StringEncoding] content:encryptedString];
    }
}

+ (void)iWithTag:(NSString*)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3){
    [sharedInstance logsCountPlus];
    
    if (tag == nil){
        tag = @"ULog";
    }
    va_list args;
    va_start(args, msg);
    NSString *str = [[NSString alloc] initWithFormat:msg arguments:args];
    va_end(args);

    [sharedInstance printLogWithLevel:ULogFilterLevelInfo withTag:tag withMessage:str];
    
    NSString *encryptedString = [sharedInstance encrypt:msg];
    if (encryptedString != nil && encryptedString.length > 0){
        [sharedInstance.mars log:(int)ULogFilterLevelInfo tag:[tag cStringUsingEncoding:NSUTF8StringEncoding] content:encryptedString];
    }
}


+ (void)wWithTag:(NSString*)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3){
    [sharedInstance logsCountPlus];
    
    if (tag == nil){
        tag = @"ULog";
    }
    
    va_list args;
    va_start(args, msg);
    NSString *str = [[NSString alloc] initWithFormat:msg arguments:args];
    va_end(args);

    [sharedInstance printLogWithLevel:ULogFilterLevelWarn withTag:tag withMessage:str];
    
    NSString *encryptedString = [sharedInstance encrypt:msg];
    if (encryptedString != nil && encryptedString.length > 0){
        [sharedInstance.mars log:(int)ULogFilterLevelWarn tag:[tag cStringUsingEncoding:NSUTF8StringEncoding] content:encryptedString];
    }
}


+ (void)eWithTag:(NSString*)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3){
    [sharedInstance logsCountPlus];
    
    if (tag == nil){
        tag = @"ULog";
    }
    
    va_list args;
    va_start(args, msg);
    NSString *str = [[NSString alloc] initWithFormat:msg arguments:args];
    va_end(args);

    [sharedInstance printLogWithLevel:ULogFilterLevelError withTag:tag withMessage:str];
    
    NSString *encryptedString = [sharedInstance encrypt:msg];
    if (encryptedString != nil && encryptedString.length > 0){
        [sharedInstance.mars log:(int)ULogFilterLevelError tag:[tag cStringUsingEncoding:NSUTF8StringEncoding] content:encryptedString];
        [sharedInstance.mars flush];
    }
}

+ (void)fWithTag:(NSString*)tag withMessage:(NSString *)msg, ... NS_FORMAT_FUNCTION(2,3){
    [sharedInstance logsCountPlus];
    
    if (tag == nil){
        tag = @"ULog";
    }
    
    va_list args;
    va_start(args, msg);
    NSString *str = [[NSString alloc] initWithFormat:msg arguments:args];
    va_end(args);

    [sharedInstance printLogWithLevel:ULogFilterLevelFatal withTag:tag withMessage:str];
    
    NSString *encryptedString = [sharedInstance encrypt:msg];
    if (encryptedString != nil && encryptedString.length > 0){
        [sharedInstance.mars log:(int)ULogFilterLevelFatal tag:[tag cStringUsingEncoding:NSUTF8StringEncoding] content:encryptedString];
        [sharedInstance.mars flush];
        
    }
}


@end

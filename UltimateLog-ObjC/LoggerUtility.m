//
//  LoggerUtility.m
//  UltimateLog-ObjC
//
//  Created by Peigen.Liu on 6/26/19.
//  Copyright © 2019 Peigen.Liu. All rights reserved.
//

#import "LoggerUtility.h"
#import "UltimateLog.h"
#import <UIKit/UIKit.h>

@implementation LoggerUtility



+ (void)printInitInfo{
    [UltimateLog vWithTag:nil withMessage:@"===========  Ultimate Log - Init Infomation ==========="];
    [UltimateLog vWithTag:nil withMessage:[NSString stringWithFormat:@"Device Name : %@",[UIDevice currentDevice].name]];
    [UltimateLog vWithTag:nil withMessage:[NSString stringWithFormat:@"System Version : %@",[UIDevice currentDevice].systemVersion]];
    [UltimateLog vWithTag:nil withMessage:[NSString stringWithFormat:@"Device Model : %@",[UIDevice currentDevice].model]];
    [UltimateLog vWithTag:nil withMessage:[NSString stringWithFormat:@"Model Name : %@",[UIDevice currentDevice].localizedModel]];
    
    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    [UltimateLog vWithTag:nil withMessage:[NSString stringWithFormat:@"App Version : %@",[infoDic objectForKey:@"CFBundleShortVersionString"]]];
    [UltimateLog vWithTag:nil withMessage:[NSString stringWithFormat:@"Build Version : %@",[infoDic objectForKey:@"CFBundleVersion"]]];
    [UltimateLog vWithTag:nil withMessage:[NSString stringWithFormat:@"App Identifier : %@",[infoDic objectForKey:@"CFBundleIdentifier"]]];
    [UltimateLog vWithTag:nil withMessage:[NSString stringWithFormat:@"App Name : %@",[infoDic objectForKey:@"CFBundleName"]]];

    [UltimateLog vWithTag:nil withMessage:@"===========  Ultimate Log - Init Infomation Done ===========\n\n"];

}



+ (NSString *)genRandStringLength:(int)len {
    static NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
    }
    return randomString;
}

@end

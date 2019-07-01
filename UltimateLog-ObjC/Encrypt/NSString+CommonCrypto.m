//
//  NSString+CommonCrypto.m
//  UltimateLog-ObjC
//
//  Created by Peigen.Liu on 6/26/19.
//  Copyright © 2019 Peigen.Liu. All rights reserved.
//

#import "NSString+CommonCrypto.h"
#import "NSData+CommonCrypto.h"

@implementation  NSString (CommonCrypto)


- (NSString *) SHA256Hex{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    
    return [[data SHA256Hash] hexString];
}




@end

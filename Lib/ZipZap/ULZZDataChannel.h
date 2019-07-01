//
//  ULZZDataChannel.h
//  ZipZap
//
//  Created by Glen Low on 12/01/13.
//  Copyright (c) 2013, Pixelglow Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ULZZChannel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ULZZDataChannel : NSObject <ULZZChannel>

@property (readonly, nullable, nonatomic) NSURL* URL;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithData:(NSData*)data NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)temporaryChannel:(out NSError**)error;
- (BOOL)replaceWithChannel:(id<ULZZChannel>)channel
					 error:(out NSError**)error;
- (void)removeAsTemporary;

- (nullable NSData*)newInput:(out NSError**)error;
- (nullable id<ULZZChannelOutput>)newOutput:(out NSError**)error;

@end

NS_ASSUME_NONNULL_END

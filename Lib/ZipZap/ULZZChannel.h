//
//  ULZZChannel.h
//  ZipZap
//
//  Created by Glen Low on 12/01/13.
//  Copyright (c) 2013, Pixelglow Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ULZZChannelOutput;

NS_ASSUME_NONNULL_BEGIN

@protocol ULZZChannel

@property (readonly, nullable, nonatomic) NSURL* URL;

- (nullable instancetype)temporaryChannel:(out NSError**)error;
- (BOOL)replaceWithChannel:(id<ULZZChannel>)channel
					 error:(out NSError**)error;
- (void)removeAsTemporary;

- (nullable NSData*)newInput:(out NSError**)error;
- (nullable id<ULZZChannelOutput>)newOutput:(out NSError**)error;

@end

NS_ASSUME_NONNULL_END

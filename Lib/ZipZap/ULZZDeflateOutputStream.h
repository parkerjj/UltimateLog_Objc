//
//  ULZZDeflateOutputStream.h
//  ZipZap
//
//  Created by Glen Low on 9/10/12.
//  Copyright (c) 2012, Pixelglow Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ULZZChannelOutput;

NS_ASSUME_NONNULL_BEGIN

@interface ULZZDeflateOutputStream : NSOutputStream

@property (readonly, nonatomic) uint32_t crc32;
@property (readonly, nonatomic) uint32_t compressedSize;
@property (readonly, nonatomic) uint32_t uncompressedSize;

- (instancetype)initWithChannelOutput:(id<ULZZChannelOutput>)channelOutput
					 compressionLevel:(NSUInteger)compressionLevel;

- (NSStreamStatus)streamStatus;
- (nullable NSError*)streamError;

- (void)open;
- (void)close;

- (NSInteger)write:(const uint8_t*)buffer maxLength:(NSUInteger)length;
- (BOOL)hasSpaceAvailable;

@end

NS_ASSUME_NONNULL_END

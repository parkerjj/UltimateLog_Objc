//
//  ULZZOldArchiveEntry.h
//  ZipZap
//
//  Created by Glen Low on 24/10/12.
//  Copyright (c) 2012, Pixelglow Software. All rights reserved.
//
//

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#include <CoreGraphics/CoreGraphics.h>
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
#include <ApplicationServices/ApplicationServices.h>
#endif

#import <Foundation/Foundation.h>

#import "ULZZArchiveEntry.h"
#import "ULZZHeaders.h"

NS_ASSUME_NONNULL_BEGIN

@interface ULZZOldArchiveEntry : ULZZArchiveEntry

@property (readonly, nonatomic) BOOL compressed;
@property (readonly, nonatomic) BOOL encrypted;
@property (readonly, nonatomic) NSDate* lastModified;
@property (readonly, nonatomic) NSUInteger crc32;
@property (readonly, nonatomic) NSUInteger compressedSize;
@property (readonly, nonatomic) NSUInteger uncompressedSize;
@property (readonly, nonatomic) mode_t fileMode;
@property (readonly, nonatomic) NSData* rawFileName;
@property (readonly, nonatomic) NSStringEncoding encoding;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithCentralFileHeader:(struct ULZZCentralFileHeader*)centralFileHeader
						  localFileHeader:(struct ULZZLocalFileHeader*)localFileHeader NS_DESIGNATED_INITIALIZER;

- (NSString*)fileNameWithEncoding:(NSStringEncoding)encoding;

@end

NS_ASSUME_NONNULL_END

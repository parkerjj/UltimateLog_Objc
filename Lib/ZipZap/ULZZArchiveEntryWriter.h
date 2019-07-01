//
//  ULZZZipEntryWriter.h
//  ZipZap
//
//  Created by Glen Low on 6/10/12.
//  Copyright (c) 2012, Pixelglow Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ULZZChannelOutput;

NS_ASSUME_NONNULL_BEGIN

@protocol ULZZArchiveEntryWriter

- (uint32_t)offsetToLocalFileEnd;
- (BOOL)writeLocalFileToChannelOutput:(id<ULZZChannelOutput>)channelOutput
					  withInitialSkip:(uint32_t)initialSkip
								error:(out NSError**)error;
- (BOOL)writeCentralFileHeaderToChannelOutput:(id<ULZZChannelOutput>)channelOutput
										error:(out NSError**)error;
@end

NS_ASSUME_NONNULL_END

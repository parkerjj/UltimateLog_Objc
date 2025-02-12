//
//  ULZZFileChannel.m
//  ZipZap
//
//  Created by Glen Low on 12/01/13.
//  Copyright (c) 2013, Pixelglow Software. All rights reserved.
//

#import "ULZZError.h"
#import "ULZZFileChannel.h"
#import "ULZZFileChannelOutput.h"

@implementation ULZZFileChannel
{
	NSURL* _URL;
}

- (instancetype)initWithURL:(NSURL*)URL
{
	if ((self = [super init]))
		_URL = URL;
	return self;
}

- (NSURL*)URL
{
	return _URL;
}

- (instancetype)temporaryChannel:(out NSError**)error
{
	NSURL* temporaryDirectory = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory
																	   inDomain:NSUserDomainMask
															  appropriateForURL:_URL
																		 create:NO
																		  error:error];
	
	return temporaryDirectory ? [[ULZZFileChannel alloc] initWithURL:[temporaryDirectory URLByAppendingPathComponent:_URL.lastPathComponent]] : nil;
}

- (BOOL)replaceWithChannel:(id<ULZZChannel>)channel
					 error:(out NSError**)error
{
	NSURL* __autoreleasing resultingURL;
	return [[NSFileManager defaultManager] replaceItemAtURL:_URL
											  withItemAtURL:channel.URL
											 backupItemName:nil
													options:0
										   resultingItemURL:&resultingURL
													  error:error];
}

- (void)removeAsTemporary
{
	[[NSFileManager defaultManager] removeItemAtURL:[_URL URLByDeletingLastPathComponent]
											  error:nil];
}

- (NSData*)newInput:(out NSError**)error
{
	return [[NSData alloc] initWithContentsOfURL:_URL
										 options:NSDataReadingMappedAlways
										   error:error];
}

- (id<ULZZChannelOutput>)newOutput:(out NSError**)error
{
	int fileDescriptor =  open(_URL.path.fileSystemRepresentation,
							   O_WRONLY | O_CREAT,
							   S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
	if (fileDescriptor == -1)
	{
		if (error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain
										 code:errno
									 userInfo:nil];
		return nil;
	}
	else
		return [[ULZZFileChannelOutput alloc] initWithFileDescriptor:fileDescriptor];
}

@end

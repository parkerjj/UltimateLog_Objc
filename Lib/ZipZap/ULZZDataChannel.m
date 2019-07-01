//
//  ULZZDataChannel.m
//  ZipZap
//
//  Created by Glen Low on 12/01/13.
//  Copyright (c) 2013, Pixelglow Software. All rights reserved.
//

#import "ULZZDataChannel.h"
#import "ULZZDataChannelOutput.h"

@implementation ULZZDataChannel
{
	NSData* _allData;
}

- (instancetype)initWithData:(NSData*)data
{
	if ((self = [super init]))
		_allData = data;
	return self;
}

- (NSURL*)URL
{
	return nil;
}

- (instancetype)temporaryChannel:(out NSError**)error
{
	return [[ULZZDataChannel alloc] initWithData:[NSMutableData data]];
}

- (BOOL)replaceWithChannel:(id<ULZZChannel>)channel
					 error:(out NSError**)error
{
	[(NSMutableData*)_allData setData:((ULZZDataChannel*)channel)->_allData];
	return YES;
}

- (void)removeAsTemporary
{
	_allData = nil;
}

- (NSData*)newInput:(out NSError**)error
{
	if (_allData.length == 0)
	{
		// no data available: consider it as file not found
		if (error)
			*error = [NSError errorWithDomain:NSCocoaErrorDomain
										 code:NSFileReadNoSuchFileError
									 userInfo:@{}];
		return nil;
	}
	return _allData;
}

- (id<ULZZChannelOutput>)newOutput:(out NSError**)error
{
	return [[ULZZDataChannelOutput alloc] initWithData:(NSMutableData*)_allData];
}

@end

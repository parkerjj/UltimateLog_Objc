//
//  ULZZArchive.mm
//  ZipZap
//
//  Created by Glen Low on 25/09/12.
//  Copyright (c) 2012, Pixelglow Software. All rights reserved.
//

#include <algorithm>
#include <fcntl.h>

#import "ULZZChannelOutput.h"
#import "ULZZDataChannel.h"
#import "ULZZError.h"
#import "ULZZFileChannel.h"
#import "ULZZScopeGuard.h"
#import "ULZZArchiveEntryWriter.h"
#import "ULZZArchive.h"
#import "ULZZHeaders.h"
#import "ULZZOldArchiveEntry.h"

static const size_t ENDOFCENTRALDIRECTORY_MAXSEARCH = sizeof(ULZZEndOfCentralDirectory) + 0xFFFF;
static const size_t ENDOFCENTRALDIRECTORY_MINSEARCH = sizeof(ULZZEndOfCentralDirectory) - sizeof(ULZZEndOfCentralDirectory::signature);

@interface ULZZArchive ()

- (instancetype)initWithChannel:(id<ULZZChannel>)channel
						options:(NSDictionary*)options
						  error:(out NSError**)error NS_DESIGNATED_INITIALIZER;

- (BOOL)loadCanMiss:(BOOL)canMiss error:(out NSError**)error;

@end

@implementation ULZZArchive
{
	id<ULZZChannel> _channel;
}

+ (instancetype)archiveWithURL:(NSURL*)URL
						 error:(out NSError**)error
{
	return [[self alloc] initWithChannel:[[ULZZFileChannel alloc] initWithURL:URL]
								 options:nil
								   error:error];
}

+ (instancetype)archiveWithData:(NSData*)data
						  error:(out NSError**)error
{
	return [[self alloc] initWithChannel:[[ULZZDataChannel alloc] initWithData:data]
								 options:nil
								   error:error];
}

- (instancetype)initWithURL:(NSURL*)URL
					options:(NSDictionary*)options
					  error:(out NSError**)error
{
	return [self initWithChannel:[[ULZZFileChannel alloc] initWithURL:URL]
						 options:options
						   error:error];
}

- (instancetype)initWithData:(NSData*)data
					 options:(NSDictionary*)options
					   error:(out NSError**)error
{
	return [self initWithChannel:[[ULZZDataChannel alloc] initWithData:data]
						 options:options
						   error:error];
}

- (instancetype)initWithChannel:(id<ULZZChannel>)channel
						options:(NSDictionary*)options
						  error:(out NSError**)error
{
	if ((self = [super init]))
	{
		_channel = channel;

		NSNumber* createIfMissing = options[ULZZOpenOptionsCreateIfMissingKey];
		if (![self loadCanMiss:createIfMissing.boolValue error:error])
			return nil;
	}
	return self;
}

- (NSURL*)URL
{
	return _channel.URL;
}

- (BOOL)loadCanMiss:(BOOL)canMiss error:(out NSError**)error
{
	// memory-map the contents from the zip file
	NSError* __autoreleasing readError;
	NSData* contents = [_channel newInput:&readError];
	if (!contents)
	{
		if (canMiss && readError.code == NSFileReadNoSuchFileError && [readError.domain isEqualToString:NSCocoaErrorDomain])
		{
			return YES;
		}
		else
			return ULZZRaiseErrorNo(error, ULZZOpenReadErrorCode, @{NSUnderlyingErrorKey : readError});
	}

	// search for the end of directory signature in last 64K of file
	const uint8_t* beginContent = (const uint8_t*)contents.bytes;
	const uint8_t* endContent = beginContent + contents.length;
	const uint8_t* beginRangeEndOfCentralDirectory = beginContent + ENDOFCENTRALDIRECTORY_MAXSEARCH < endContent ? endContent - ENDOFCENTRALDIRECTORY_MAXSEARCH : beginContent;
	const uint8_t* endRangeEndOfCentralDirectory = beginContent + ENDOFCENTRALDIRECTORY_MINSEARCH < endContent ? endContent - ENDOFCENTRALDIRECTORY_MINSEARCH : beginContent;
	const uint32_t sign = ULZZEndOfCentralDirectory::sign;
	const uint8_t* endOfCentralDirectory = std::find_end(beginRangeEndOfCentralDirectory,
														 endRangeEndOfCentralDirectory,
														 (const uint8_t*)&sign,
														 (const uint8_t*)(&sign + 1));
	const ULZZEndOfCentralDirectory* endOfCentralDirectoryRecord = (const ULZZEndOfCentralDirectory*)endOfCentralDirectory;
	
	// sanity check:
	if (
		// found the end of central directory signature
		endOfCentralDirectory == endRangeEndOfCentralDirectory
		// single disk zip
		|| endOfCentralDirectoryRecord->numberOfThisDisk != 0
		|| endOfCentralDirectoryRecord->numberOfTheDiskWithTheStartOfTheCentralDirectory != 0
		|| endOfCentralDirectoryRecord->totalNumberOfEntriesInTheCentralDirectoryOnThisDisk
			!= endOfCentralDirectoryRecord->totalNumberOfEntriesInTheCentralDirectory
		// central directory occurs before end of central directory, and has enough minimal space for the given entries
		|| beginContent
			+ endOfCentralDirectoryRecord->offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber
			+ endOfCentralDirectoryRecord->totalNumberOfEntriesInTheCentralDirectory * sizeof(ULZZCentralFileHeader)
			> endOfCentralDirectory
		// end of central directory occurs at actual end of the zip
		|| endContent
			!= endOfCentralDirectory + sizeof(ULZZEndOfCentralDirectory) + endOfCentralDirectoryRecord->zipFileCommentLength)
		return ULZZRaiseErrorNo(error, ULZZEndOfCentralDirectoryReadErrorCode, nil);
			
	// add an entry for each central header in the sequence
	ULZZCentralFileHeader* nextCentralFileHeader = (ULZZCentralFileHeader*)(beginContent
																		+ endOfCentralDirectoryRecord->offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber);
	NSMutableArray<ULZZArchiveEntry*>* entries = [NSMutableArray array];
	for (NSUInteger index = 0; index < endOfCentralDirectoryRecord->totalNumberOfEntriesInTheCentralDirectory; ++index)
	{
		// sanity check:
		if (
			// correct signature
			nextCentralFileHeader->sign != ULZZCentralFileHeader::sign
			// single disk zip
			|| nextCentralFileHeader->diskNumberStart != 0
			// local file occurs before first central file header, and has enough minimal space for at least local file
			|| nextCentralFileHeader->relativeOffsetOfLocalHeader + sizeof(ULZZLocalFileHeader)
				> endOfCentralDirectoryRecord->offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber
			// next central file header in sequence is within the central directory
			|| (const uint8_t*)nextCentralFileHeader->nextCentralFileHeader() > endOfCentralDirectory)
			return ULZZRaiseErrorNo(error, ULZZCentralFileHeaderReadErrorCode, @{ULZZEntryIndexKey : @(index)});
								
		ULZZLocalFileHeader* nextLocalFileHeader = (ULZZLocalFileHeader*)(beginContent
																	  + nextCentralFileHeader->relativeOffsetOfLocalHeader);
		
		[entries addObject:[[ULZZOldArchiveEntry alloc] initWithCentralFileHeader:nextCentralFileHeader
																localFileHeader:nextLocalFileHeader]];
		
		nextCentralFileHeader = nextCentralFileHeader->nextCentralFileHeader();
	}
	
	// having successfully negotiated the new contents + entries, replace in one go
	_contents = contents;
	_entries = entries;
	return YES;
}

- (BOOL)updateEntries:(NSArray<ULZZArchiveEntry*>*)newEntries
				error:(out NSError**)error
{
	// determine how many entries to skip, where initial old and new entries match
	NSUInteger oldEntriesCount = _entries.count;
	NSUInteger newEntriesCount = newEntries.count;
	NSUInteger skipIndex;
	for (skipIndex = 0; skipIndex < std::min(oldEntriesCount, newEntriesCount); ++skipIndex)
		if (newEntries[skipIndex] != _entries[skipIndex])
			break;
	
	// get an entry writer for each new entry
	NSMutableArray<id<ULZZArchiveEntryWriter>>* newEntryWriters = [NSMutableArray array];
    
    [newEntries enumerateObjectsUsingBlock:^(ULZZArchiveEntry *anEntry, NSUInteger index, BOOL* stop)
     {
         [newEntryWriters addObject:[anEntry newWriterCanSkipLocalFile:index < skipIndex]];
     }];
	
	// skip the initial matching entries
	uint32_t initialSkip = skipIndex > 0 ? [newEntryWriters[skipIndex - 1] offsetToLocalFileEnd] : 0;

	NSError* __autoreleasing underlyingError;

	// create a temp channel for all output
	id<ULZZChannel> temporaryChannel = [_channel temporaryChannel:&underlyingError];
	if (!temporaryChannel)
		return ULZZRaiseErrorNo(error, ULZZOpenWriteErrorCode, @{NSUnderlyingErrorKey : underlyingError});
	ULZZScopeGuard temporaryChannelRemover(^{[temporaryChannel removeAsTemporary];});
	
	{
		// open the channel
		id<ULZZChannelOutput> temporaryChannelOutput = [temporaryChannel newOutput:&underlyingError];
		if (!temporaryChannelOutput)
			return ULZZRaiseErrorNo(error, ULZZOpenWriteErrorCode, @{NSUnderlyingErrorKey : underlyingError});
		ULZZScopeGuard temporaryChannelOutputCloser(^{[temporaryChannelOutput close];});
	
		// write out local files
		for (NSUInteger index = skipIndex; index < newEntriesCount; ++index)
			if (![newEntryWriters[index] writeLocalFileToChannelOutput:temporaryChannelOutput
																	  withInitialSkip:initialSkip
																				error:&underlyingError])
				return ULZZRaiseErrorNo(error, ULZZLocalFileWriteErrorCode, @{NSUnderlyingErrorKey : underlyingError, ULZZEntryIndexKey : @(index)});
		
		ULZZEndOfCentralDirectory endOfCentralDirectory;
		endOfCentralDirectory.signature = ULZZEndOfCentralDirectory::sign;
		endOfCentralDirectory.numberOfThisDisk
			= endOfCentralDirectory.numberOfTheDiskWithTheStartOfTheCentralDirectory
			= 0;
		endOfCentralDirectory.totalNumberOfEntriesInTheCentralDirectoryOnThisDisk
			= endOfCentralDirectory.totalNumberOfEntriesInTheCentralDirectory
			= newEntriesCount;
		endOfCentralDirectory.offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber = [temporaryChannelOutput offset] + initialSkip;
		
		// write out central file headers
		for (NSUInteger index = 0; index < newEntriesCount; ++index)
			if (![newEntryWriters[index] writeCentralFileHeaderToChannelOutput:temporaryChannelOutput
																						error:&underlyingError])
				return ULZZRaiseErrorNo(error, ULZZCentralFileHeaderWriteErrorCode, @{NSUnderlyingErrorKey : underlyingError, ULZZEntryIndexKey : @(index)});
		
		endOfCentralDirectory.sizeOfTheCentralDirectory = [temporaryChannelOutput offset] + initialSkip
			- endOfCentralDirectory.offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber;
		endOfCentralDirectory.zipFileCommentLength = 0;
		
		// write out the end of central directory
		if (![temporaryChannelOutput writeData:[NSData dataWithBytesNoCopy:&endOfCentralDirectory
																	length:sizeof(endOfCentralDirectory)
															  freeWhenDone:NO]
										 error:&underlyingError])
			return ULZZRaiseErrorNo(error, ULZZEndOfCentralDirectoryWriteErrorCode, @{NSUnderlyingErrorKey : underlyingError});
	}
	
	if (initialSkip)
	{
		// something skipped, append the temporary channel contents at the skipped offset
		id<ULZZChannelOutput> channelOutput = [_channel newOutput:&underlyingError];
		if (!channelOutput)
			return ULZZRaiseErrorNo(error, ULZZReplaceWriteErrorCode, @{NSUnderlyingErrorKey : underlyingError});
		ULZZScopeGuard channelOutputCloser(^{[channelOutput close];});

		NSData* channelInput = [temporaryChannel newInput:&underlyingError];
		if (!channelInput
			|| ![channelOutput seekToOffset:initialSkip
									  error:&underlyingError]
			|| ![channelOutput writeData:channelInput
								   error:&underlyingError]
			|| ![channelOutput truncateAtOffset:[channelOutput offset]
										  error:&underlyingError])
			return ULZZRaiseErrorNo(error, ULZZReplaceWriteErrorCode, @{NSUnderlyingErrorKey : underlyingError});
		
	}
	else
		// nothing skipped, temporary channel is entire contents: simply replace the original
		if (![_channel replaceWithChannel:temporaryChannel
									error:&underlyingError])
			return ULZZRaiseErrorNo(error, ULZZReplaceWriteErrorCode, @{NSUnderlyingErrorKey : underlyingError});
	
	// reload entries + content
	return [self loadCanMiss:NO error:error];
}

@end


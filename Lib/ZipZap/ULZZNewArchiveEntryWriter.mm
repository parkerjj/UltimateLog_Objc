//
//  ULZZNewArchiveEntryWriter.m
//  ZipZap
//
//  Created by Glen Low on 9/10/12.
//  Copyright (c) 2012, Pixelglow Software. All rights reserved.
//

#include <zlib.h>

#import "ULZZChannelOutput.h"
#import "ULZZDeflateOutputStream.h"
#import "ULZZError.h"
#import "ULZZHeaders.h"
#import "ULZZNewArchiveEntryWriter.h"
#import "ULZZScopeGuard.h"
#import "ULZZStoreOutputStream.h"

namespace ULZZDataConsumer
{
	static size_t putBytes (void* info, const void* buffer, size_t count)
	{
		return [(__bridge ULZZDeflateOutputStream*)info write:(const uint8_t*)buffer maxLength:count];
	}

	static CGDataConsumerCallbacks callbacks =
	{
		&putBytes,
		NULL
	};
}

@interface ULZZNewArchiveEntryWriter ()

- (ULZZCentralFileHeader*)centralFileHeader;
- (ULZZLocalFileHeader*)localFileHeader;

@end

@implementation ULZZNewArchiveEntryWriter
{
	NSMutableData* _centralFileHeader;
	NSMutableData* _localFileHeader;
	NSInteger _compressionLevel;
	NSData* (^_dataBlock)(NSError** error);
	BOOL (^_streamBlock)(NSOutputStream* stream, NSError** error);
	BOOL (^_dataConsumerBlock)(CGDataConsumerRef dataConsumer, NSError** error);
}

- (instancetype)initWithFileName:(NSString*)fileName
						fileMode:(mode_t)fileMode
					lastModified:(NSDate*)lastModified
				compressionLevel:(NSInteger)compressionLevel
					   dataBlock:(NSData*(^)(NSError** error))dataBlock
					 streamBlock:(BOOL(^)(NSOutputStream* stream, NSError** error))streamBlock
			   dataConsumerBlock:(BOOL(^)(CGDataConsumerRef dataConsumer, NSError** error))dataConsumerBlock
{
	if ((self = [super init]))
	{
		// allocate central, local file headers with enough space for file name
		NSUInteger fileNameLength = [fileName lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
		_centralFileHeader = [[NSMutableData alloc] initWithLength:sizeof(ULZZCentralFileHeader) + fileNameLength];
		_localFileHeader = [[NSMutableData alloc] initWithLength:sizeof(ULZZLocalFileHeader) + fileNameLength];
		
		ULZZCentralFileHeader* centralFileHeader = [self centralFileHeader];
		centralFileHeader->signature = ULZZCentralFileHeader::sign;

		ULZZLocalFileHeader* localFileHeader = [self localFileHeader];
		localFileHeader->signature = ULZZLocalFileHeader::sign;

		// made by = 3.0, needed to extract = 1.0
		centralFileHeader->versionMadeBy = 0x1e;
		centralFileHeader->fileAttributeCompatibility = ULZZFileAttributeCompatibility::unix;
		centralFileHeader->versionNeededToExtract = localFileHeader->versionNeededToExtract = 0x000a;
		
		// general purpose flag = approximate compression level + use of data descriptor (bit 3) + language encoding flag (EFS, bit 11)
		ULZZGeneralPurposeBitFlag compressionFlag;
		switch (compressionLevel)
		{
			case -1:
			default:
				compressionFlag = ULZZGeneralPurposeBitFlag::normalCompression;
				break;
			case 1:
			case 2:
				// super fast (-es)
				compressionFlag = ULZZGeneralPurposeBitFlag::superFastCompression;
				break;
			case 3:
			case 4:
				// fast (-ef)
				compressionFlag = ULZZGeneralPurposeBitFlag::fastCompression;
				break;
			case 5:
			case 6:
			case 7:
				// normal (-en)
				compressionFlag = ULZZGeneralPurposeBitFlag::normalCompression;
				break;
			case 8:
			case 9:
				// maximum (-ex)
				compressionFlag = ULZZGeneralPurposeBitFlag::maximumCompression;
				break;
		}
		
		// use data descriptor for crc + size if any blocks provided
		ULZZGeneralPurposeBitFlag sizeInDataDescriptorFlag = dataBlock || streamBlock || dataConsumerBlock ? ULZZGeneralPurposeBitFlag::sizeInDataDescriptor : ULZZGeneralPurposeBitFlag::none;
		centralFileHeader->generalPurposeBitFlag = localFileHeader->generalPurposeBitFlag = compressionFlag | sizeInDataDescriptorFlag | ULZZGeneralPurposeBitFlag::languageEncoding;

		centralFileHeader->compressionMethod = localFileHeader->compressionMethod = compressionLevel ? ULZZCompressionMethod::deflated : ULZZCompressionMethod::stored;
		
		// convert last modified Foundation date into MS-DOS time + date
		NSCalendar* gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
		NSDateComponents* lastModifiedComponents = [gregorianCalendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
													| NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond
																		fromDate:lastModified];
		centralFileHeader->lastModFileTime = localFileHeader->lastModFileTime = (lastModifiedComponents.second + 1) >> 1 | lastModifiedComponents.minute << 5 | lastModifiedComponents.hour << 11;
		centralFileHeader->lastModFileDate = localFileHeader->lastModFileDate = lastModifiedComponents.day | lastModifiedComponents.month << 5 | (lastModifiedComponents.year - 1980) << 9;
		
		// crc32, compressed size and uncompressed size are zero; real values will be computed and written in data descriptor
		centralFileHeader->crc32 = localFileHeader->crc32 = 0;
		centralFileHeader->compressedSize = localFileHeader->compressedSize = 0;
		centralFileHeader->uncompressedSize = localFileHeader->uncompressedSize = 0;
		
		centralFileHeader->fileNameLength = localFileHeader->fileNameLength = fileNameLength;
		centralFileHeader->extraFieldLength = localFileHeader->extraFieldLength = 0;
		centralFileHeader->fileCommentLength = 0;
		
		centralFileHeader->diskNumberStart = 0;
		
		// external file attributes are UNIX file attributes
		centralFileHeader->internalFileAttributes = 0;
		centralFileHeader->externalFileAttributes = fileMode << 16;
		
		// relative offset is zero but will be updated when local file is written
		centralFileHeader->relativeOffsetOfLocalHeader = 0;
		
		// filename is at end of central header, local header
		NSRange fileNameRange = NSMakeRange(0, fileName.length);
		[fileName getBytes:centralFileHeader->fileName()
				 maxLength:fileNameLength
				usedLength:NULL
				  encoding:NSUTF8StringEncoding
				   options:0
					 range:fileNameRange
			remainingRange:NULL];
		[fileName getBytes:localFileHeader->fileName()
				 maxLength:fileNameLength
				usedLength:NULL
				  encoding:NSUTF8StringEncoding
				   options:0
					 range:fileNameRange
			remainingRange:NULL];
		
		_compressionLevel = compressionLevel;
		_dataBlock = dataBlock;
		_streamBlock = streamBlock;
		_dataConsumerBlock = dataConsumerBlock;
	}
	return self;
}

- (ULZZCentralFileHeader*)centralFileHeader
{
	return (ULZZCentralFileHeader*)_centralFileHeader.mutableBytes;
}

- (ULZZLocalFileHeader*)localFileHeader
{
	return (ULZZLocalFileHeader*)_localFileHeader.mutableBytes;
}

- (uint32_t)offsetToLocalFileEnd
{
	return 0;
}

- (BOOL)writeLocalFileToChannelOutput:(id<ULZZChannelOutput>)channelOutput
					  withInitialSkip:(uint32_t)initialSkip
								error:(out NSError**)error
{
	ULZZCentralFileHeader* centralFileHeader = [self centralFileHeader];
	
	// save current offset, then write out all of local file to the file handle
	centralFileHeader->relativeOffsetOfLocalHeader = [channelOutput offset] + initialSkip;
	if (![channelOutput writeData:_localFileHeader
							error:error])
		return NO;
	
	ULZZDataDescriptor dataDescriptor;
	dataDescriptor.signature = ULZZDataDescriptor::sign;
	dataDescriptor.crc32 = 0;
	dataDescriptor.compressedSize = dataDescriptor.uncompressedSize = 0;

	{
		// if any of the blocks don't set the error, ensure we return an error anyway
		ULZZScopeGuard errorChecker(^
								  {
									  if (error && !*error)
										  *error = [NSError errorWithDomain:ULZZErrorDomain
																	   code:ULZZBlockFailedWithoutError
																   userInfo:nil];
								  });

		if (_compressionLevel)
		{
			// use of one the blocks to write to a stream that deflates directly to the output file handle
			ULZZDeflateOutputStream* outputStream = [[ULZZDeflateOutputStream alloc] initWithChannelOutput:channelOutput
																					  compressionLevel:_compressionLevel];
			{
				[outputStream open];
				ULZZScopeGuard outputStreamCloser(^{[outputStream close];});
				
				
				if (_dataBlock)
				{
					NSError* err = nil;
					BOOL bad = YES;
					@autoreleasepool
					{
						NSData* data = _dataBlock(&err);
						if (data)
						{
							const uint8_t* bytes;
							NSUInteger bytesToWrite;
							NSUInteger bytesWritten;
							for (bytes = (const uint8_t*)data.bytes, bytesToWrite = data.length;
								 bytesToWrite > 0;
								 bytes += bytesWritten, bytesToWrite -= bytesWritten)
								bytesWritten = [outputStream write:bytes maxLength:bytesToWrite];
							
							bad = NO;
						}
					}
					if (bad)
					{
						*error = err;
						return NO;
					}
					
				}
				else if (_streamBlock)
				{
					if (!_streamBlock(outputStream, error))
						return NO;
				}
				else if (_dataConsumerBlock)
				{
					CGDataConsumerRef dataConsumer = CGDataConsumerCreate((__bridge void*)outputStream, &ULZZDataConsumer::callbacks);
					ULZZScopeGuard dataConsumerReleaser(^{CGDataConsumerRelease(dataConsumer);});

					if (!_dataConsumerBlock(dataConsumer, error))
						return NO;
				}
			}
			
			dataDescriptor.crc32 = outputStream.crc32;
			dataDescriptor.compressedSize = outputStream.compressedSize;
			dataDescriptor.uncompressedSize = outputStream.uncompressedSize;
		}
		else
		{
			if (_dataBlock)
			{
				NSError* err = nil;
				BOOL bad = YES;
				@autoreleasepool
				{
					// if data block, write the data directly to output file handle
					NSData* data = _dataBlock(&err);
					if (data && [channelOutput writeData:data error:&err])
					{
						dataDescriptor.compressedSize = dataDescriptor.uncompressedSize = (uint32_t)data.length;
						dataDescriptor.crc32 = (uint32_t)crc32(0, (const Bytef*)data.bytes, dataDescriptor.uncompressedSize);
						bad = NO;
					}
				}
				
				if (bad)
				{
					*error = err;
					return NO;
				}
			}
			else
			{
				// if stream block, data consumer block or no block, use to write to a stream that just outputs to the output file handle
				ULZZStoreOutputStream* outputStream = [[ULZZStoreOutputStream alloc] initWithChannelOutput:channelOutput];
				
				{
					[outputStream open];
					ULZZScopeGuard outputStreamCloser(^{[outputStream close];});
					
					if (_streamBlock)
					{
						if (!_streamBlock(outputStream, error))
							return NO;
					}
					else if (_dataConsumerBlock)
					{
						CGDataConsumerRef dataConsumer = CGDataConsumerCreate((__bridge void*)outputStream, &ULZZDataConsumer::callbacks);
						ULZZScopeGuard dataConsumerReleaser(^{CGDataConsumerRelease(dataConsumer);});
						
						if (!_dataConsumerBlock(dataConsumer, error))
							return NO;
					}
				}
				
				dataDescriptor.crc32 = outputStream.crc32;
				dataDescriptor.compressedSize = dataDescriptor.uncompressedSize = outputStream.size;
			}
		}
	}
	// save the crc32, compressedSize, uncompressedSize, then write out the data descriptor if any blocks provided
	centralFileHeader->crc32 = dataDescriptor.crc32;
	centralFileHeader->compressedSize = dataDescriptor.compressedSize;
	centralFileHeader->uncompressedSize = dataDescriptor.uncompressedSize;
	if ((_dataBlock || _streamBlock || _dataConsumerBlock) &&
		![channelOutput writeData:[NSData dataWithBytesNoCopy:&dataDescriptor
													   length:sizeof(dataDescriptor)
												 freeWhenDone:NO]
							error:error])
		return NO;
	
	return YES;
}

- (BOOL)writeCentralFileHeaderToChannelOutput:(id<ULZZChannelOutput>)channelOutput
										error:(out NSError**)error

{
	return [channelOutput writeData:_centralFileHeader
							  error:error];
}

@end

//
//  ULZZOldArchiveEntry.m
//  ZipZap
//
//  Created by Glen Low on 24/10/12.
//  Copyright (c) 2012, Pixelglow Software. All rights reserved.
//
//

#include <zlib.h>

#import "ULZZDataProvider.h"
#import "ULZZError.h"
#import "ULZZInflateInputStream.h"
#import "ULZZOldArchiveEntry.h"
#import "ULZZOldArchiveEntryWriter.h"
#import "ULZZHeaders.h"
#import "ULZZArchiveEntryWriter.h"
#import "ULZZScopeGuard.h"
#import "ULZZStandardDecryptInputStream.h"
#import "ULZZAESDecryptInputStream.h"
#import "ULZZConstants.h"

@interface ULZZOldArchiveEntry ()

- (NSData*)fileData;

- (BOOL)checkEncryptionAndCompression:(out NSError**)error;
- (NSInputStream*)streamForData:(NSData*)data withPassword:(NSString*)password error:(out NSError**)error;

@end

@implementation ULZZOldArchiveEntry
{
	ULZZCentralFileHeader* _centralFileHeader;
	ULZZLocalFileHeader* _localFileHeader;
	ULZZEncryptionMode _encryptionMode;
}

- (instancetype)initWithCentralFileHeader:(struct ULZZCentralFileHeader*)centralFileHeader
						  localFileHeader:(struct ULZZLocalFileHeader*)localFileHeader
{
	if ((self = [super init]))
	{
		_centralFileHeader = centralFileHeader;
		_localFileHeader = localFileHeader;
		
		if ((_centralFileHeader->generalPurposeBitFlag & ULZZGeneralPurposeBitFlag::encrypted) != ULZZGeneralPurposeBitFlag::none)
		{
			ULZZWinZipAESExtraField *winZipAESRecord = _centralFileHeader->extraField<ULZZWinZipAESExtraField>();
			if (winZipAESRecord)
				_encryptionMode = ULZZEncryptionModeWinZipAES;
			else if ((_centralFileHeader->generalPurposeBitFlag & ULZZGeneralPurposeBitFlag::encryptionStrong) != ULZZGeneralPurposeBitFlag::none)
				_encryptionMode = ULZZEncryptionModeStrong;
			else
				_encryptionMode = ULZZEncryptionModeStandard;
		}
		else
			_encryptionMode = ULZZEncryptionModeNone;
	}
	return self;
}


- (NSData*)fileData
{
	uint8_t* dataStart = _localFileHeader->fileData();
	NSUInteger dataLength = _centralFileHeader->compressedSize;
	
	// adjust for any standard encryption header
	if (_encryptionMode == ULZZEncryptionModeStandard)
	{
		dataStart += 12;
		dataLength -= 12;
	}
	else if (_encryptionMode == ULZZEncryptionModeWinZipAES)
	{
		ULZZWinZipAESExtraField *winZipAESRecord = _localFileHeader->extraField<ULZZWinZipAESExtraField>();
		if (winZipAESRecord)
		{
			size_t saltLength = getSaltLength(winZipAESRecord->encryptionStrength);
			dataStart += saltLength + 2; // saltLength + password verifier length
			dataLength -= saltLength + 2 + 10; // saltLength + password verifier + authentication stuff
		}
	}

	return [NSData dataWithBytesNoCopy:dataStart length:dataLength freeWhenDone:NO];
}

- (ULZZCompressionMethod)compressionMethod
{
    if (_encryptionMode == ULZZEncryptionModeWinZipAES)
	{
		ULZZWinZipAESExtraField *winZipAESRecord = _centralFileHeader->extraField<ULZZWinZipAESExtraField>();
		if (winZipAESRecord)
			return winZipAESRecord->compressionMethod;
	}
	return _centralFileHeader->compressionMethod;
}

- (BOOL)compressed
{
	return self.compressionMethod != ULZZCompressionMethod::stored;
}

- (BOOL)encrypted
{
	return (_centralFileHeader->generalPurposeBitFlag & ULZZGeneralPurposeBitFlag::encrypted) != ULZZGeneralPurposeBitFlag::none;
}

- (NSDate*)lastModified
{
	// convert last modified MS-DOS time, date into a Foundation date
	
	NSDateComponents* dateComponents = [[NSDateComponents alloc] init];
	dateComponents.second = (_centralFileHeader->lastModFileTime & 0x1F) << 1;
	dateComponents.minute = (_centralFileHeader->lastModFileTime & 0x7E0) >> 5;
	dateComponents.hour = (_centralFileHeader->lastModFileTime & 0xF800) >> 11;
	dateComponents.day = _centralFileHeader->lastModFileDate & 0x1F;
	dateComponents.month = (_centralFileHeader->lastModFileDate & 0x1E0) >> 5;
	dateComponents.year = ((_centralFileHeader->lastModFileDate & 0xFE00) >> 9) + 1980;
	
	return [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] dateFromComponents:dateComponents];
}

- (NSUInteger)crc32
{
	return _centralFileHeader->crc32;
}

- (NSUInteger)compressedSize
{
	return _centralFileHeader->compressedSize;
}

- (NSUInteger)uncompressedSize
{
	return _centralFileHeader->uncompressedSize;
}

- (mode_t)fileMode
{
	uint32_t externalFileAttributes = _centralFileHeader->externalFileAttributes;
	switch (_centralFileHeader->fileAttributeCompatibility)
	{
		case ULZZFileAttributeCompatibility::msdos:
		case ULZZFileAttributeCompatibility::ntfs:
			// if we have MS-DOS or NTFS file attributes, synthesize UNIX ones from them
			return S_IRUSR | S_IRGRP | S_IROTH
				| (externalFileAttributes & static_cast<uint32_t>(ULZZMSDOSAttributes::readonly) ? 0 : S_IWUSR)
            | (externalFileAttributes & (static_cast<uint32_t>(ULZZMSDOSAttributes::subdirectory) | static_cast<uint32_t>(ULZZMSDOSAttributes::volume)) ? S_IFDIR | S_IXUSR | S_IXGRP | S_IXOTH : S_IFREG);
		case ULZZFileAttributeCompatibility::unix:
			// if we have UNIX file attributes, they are in the high 16 bits
			return externalFileAttributes >> 16;
		default:
			return 0;
	}
}

- (NSData*)rawFileName
{
	return [NSData dataWithBytes:_centralFileHeader->fileName()
						  length:_centralFileHeader->fileNameLength];
}

- (NSStringEncoding)encoding
{
	return (_centralFileHeader->generalPurposeBitFlag & ULZZGeneralPurposeBitFlag::languageEncoding) == ULZZGeneralPurposeBitFlag::none ?
		CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSLatinUS) : // CP-437
		NSUTF8StringEncoding; // UTF-8
}

- (BOOL)check:(out NSError**)error
{
	// descriptor fields either from local file header or data descriptor
	uint32_t dataDescriptorSignature;
	uint32_t localCrc32;
	uint32_t localCompressedSize;
	uint32_t localUncompressedSize;
	if ((_localFileHeader->generalPurposeBitFlag & ULZZGeneralPurposeBitFlag::sizeInDataDescriptor) == ULZZGeneralPurposeBitFlag::none)
	{
		dataDescriptorSignature = ULZZDataDescriptor::sign;
		localCrc32 = _localFileHeader->crc32;
		localCompressedSize = _localFileHeader->compressedSize;
		localUncompressedSize = _localFileHeader->uncompressedSize;
	}
	else
	{
		const ULZZDataDescriptor* dataDescriptor = _localFileHeader->dataDescriptor(_localFileHeader->compressedSize);
		dataDescriptorSignature = dataDescriptor->signature;
		localCrc32 = dataDescriptor->crc32;
		localCompressedSize = dataDescriptor->compressedSize;
		localUncompressedSize = dataDescriptor->uncompressedSize;
	}
	
	// figure out local encryption mode
	ULZZEncryptionMode localEncryptionMode;
	if ((_localFileHeader->generalPurposeBitFlag & ULZZGeneralPurposeBitFlag::encrypted) != ULZZGeneralPurposeBitFlag::none)
	{
		ULZZWinZipAESExtraField *winZipAESRecord = _localFileHeader->extraField<ULZZWinZipAESExtraField>();
		
		if (winZipAESRecord)
			localEncryptionMode = ULZZEncryptionModeWinZipAES;
		else if ((_localFileHeader->generalPurposeBitFlag & ULZZGeneralPurposeBitFlag::encryptionStrong) != ULZZGeneralPurposeBitFlag::none)
			localEncryptionMode = ULZZEncryptionModeStrong;
		else
			localEncryptionMode = ULZZEncryptionModeStandard;
	}
	else
		localEncryptionMode = ULZZEncryptionModeNone;
	
	// sanity check:
	if (
		// correct signature
		_localFileHeader->signature != ULZZLocalFileHeader::sign
		// general fields in local and central headers match
		|| _localFileHeader->versionNeededToExtract != _centralFileHeader->versionNeededToExtract
		|| _localFileHeader->generalPurposeBitFlag != _centralFileHeader->generalPurposeBitFlag
		|| _localFileHeader->compressionMethod != self.compressionMethod
		|| _localFileHeader->lastModFileDate != _centralFileHeader->lastModFileDate
		|| _localFileHeader->lastModFileTime != _centralFileHeader->lastModFileTime
		|| _localFileHeader->fileNameLength != _centralFileHeader->fileNameLength
		// file name in local and central headers match
		|| memcmp(_localFileHeader->fileName(), _centralFileHeader->fileName(), _localFileHeader->fileNameLength) != 0
		// descriptor fields in local and central headers match
		|| dataDescriptorSignature != ULZZDataDescriptor::sign
		|| localCrc32 != _centralFileHeader->crc32
		|| localCompressedSize != _centralFileHeader->compressedSize
		|| localUncompressedSize != _centralFileHeader->uncompressedSize
		|| localEncryptionMode != _encryptionMode)
		return ULZZRaiseErrorNo(error, ULZZLocalFileReadErrorCode, nil);
	
	if (_encryptionMode == ULZZEncryptionModeStandard)
	{
		// validate encrypted CRC (?)
		unsigned char crcBytes[4];
		memcpy(&crcBytes[0], &_centralFileHeader->crc32, 4);
		
		crcBytes[3] = (crcBytes[3] & 0xFF);
		crcBytes[2] = ((crcBytes[3] >> 8) & 0xFF);
		crcBytes[1] = ((crcBytes[3] >> 16) & 0xFF);
		crcBytes[0] = ((crcBytes[3] >> 24) & 0xFF);
		
		if (crcBytes[2] > 0 || crcBytes[1] > 0 || crcBytes[0] > 0)
			return ULZZRaiseErrorNo(error, ULZZInvalidCRChecksum, @{});
	}
	
	return YES;
}

- (NSString*)fileNameWithEncoding:(NSStringEncoding)encoding
{
	return [[NSString alloc] initWithBytes:_centralFileHeader->fileName()
									length:_centralFileHeader->fileNameLength
								  encoding:encoding];
}

- (BOOL)checkEncryptionAndCompression:(out NSError**)error
{
	switch (_encryptionMode)
	{
		case ULZZEncryptionModeNone:
		case ULZZEncryptionModeStandard:
		case ULZZEncryptionModeWinZipAES:
			break;
		default:
			return ULZZRaiseErrorNo(error, ULZZUnsupportedEncryptionMethod, @{});
	}
	
	switch (self.compressionMethod)
	{
		case ULZZCompressionMethod::stored:
		case ULZZCompressionMethod::deflated:
			break;
		default:
			return ULZZRaiseErrorNo(error, ULZZUnsupportedCompressionMethod, @{});
	}
	
	return YES;
}

- (NSInputStream*)streamForData:(NSData*)data withPassword:(NSString*)password error:(out NSError**)error
{
	// We need to output an error, becase in AES we have (most of the time) knowledge about the password verification even before starting to decrypt. So we should not supply a stream when we KNOW that the password is wrong.
	
	NSInputStream* dataStream = [NSInputStream inputStreamWithData:data];
	
	// decrypt if needed
	NSInputStream* decryptedStream;
	switch (_encryptionMode)
	{
		case ULZZEncryptionModeNone:
			decryptedStream = dataStream;
			break;
		case ULZZEncryptionModeStandard:
			// to check the password: if CRC32 in data descriptor, use lastModFileTime; otherwise use high word of CRC32
			decryptedStream = [[ULZZStandardDecryptInputStream alloc] initWithStream:dataStream
																		  password:password
																			header:_localFileHeader->fileData()
																			 check:(_centralFileHeader->generalPurposeBitFlag & ULZZGeneralPurposeBitFlag::sizeInDataDescriptor) == ULZZGeneralPurposeBitFlag::none ? (_centralFileHeader->crc32 >> 16) : _centralFileHeader->lastModFileTime
																		   version:_centralFileHeader->versionMadeBy
																			 error:error];
			break;
		case ULZZEncryptionModeWinZipAES:
			decryptedStream = [[ULZZAESDecryptInputStream alloc] initWithStream:dataStream
																	 password:password
																	   header:_localFileHeader->fileData()
																	 strength:_localFileHeader->extraField<ULZZWinZipAESExtraField>()->encryptionStrength
																		error:error];
			break;
		default:
			decryptedStream = nil;
			break;
	}
	if (!decryptedStream)
		return nil;

	// decompress if needed
	NSInputStream* decompressedDecryptedStream;
	switch (self.compressionMethod)
	{
		case ULZZCompressionMethod::stored:
			decompressedDecryptedStream = decryptedStream;
			break;
		case ULZZCompressionMethod::deflated:
			decompressedDecryptedStream = [[ULZZInflateInputStream alloc] initWithStream:decryptedStream];
			break;
		default:
			decompressedDecryptedStream = nil;
			break;
	}
	
	return decompressedDecryptedStream;
}

- (NSInputStream*)newStreamWithPassword:(NSString*)password error:(out NSError**)error
{
	if (![self checkEncryptionAndCompression:error])
		return nil;

	NSData* fileData = [self fileData];
	return [self streamForData:fileData withPassword:password error:error];
}

- (NSData*)newDataWithPassword:(NSString*)password error:(out NSError**)error
{
	if (![self checkEncryptionAndCompression:error])
		return nil;
	
	NSData* fileData = [self fileData];
	
	if (_encryptionMode == ULZZEncryptionModeNone)
		switch (self.compressionMethod)
		{
			case ULZZCompressionMethod::stored:
				// unencrypted, stored: just return as-is. Make sure to create a new object since [NSData copy] returns the same object on pre-10.9 systems.
				return [[NSData alloc] initWithBytes:fileData.bytes length:fileData.length];
			case ULZZCompressionMethod::deflated:
				// unencrypted, deflated: inflate in one go
				return [ULZZInflateInputStream decompressData:fileData
									   withUncompressedSize:_centralFileHeader->uncompressedSize];
			default:
				return nil;
		}
	else
	{
		NSInputStream* stream = [self streamForData:fileData withPassword:password error:error];
		if (!stream) return nil;
		
		NSMutableData* data = [NSMutableData dataWithLength:_centralFileHeader->uncompressedSize];
		
		[stream open];
		ULZZScopeGuard streamCloser(^{[stream close];});
		
		// read until all decompressed or EOF (should not happen since we know uncompressed size) or error
		NSUInteger totalBytesRead = 0;
		while (totalBytesRead < _centralFileHeader->uncompressedSize)
		{
			NSInteger bytesRead = [stream read:(uint8_t*)data.mutableBytes + totalBytesRead
									 maxLength:_centralFileHeader->uncompressedSize - totalBytesRead];
			if (bytesRead > 0)
				totalBytesRead += bytesRead;
			else
				break;
		}
		if (stream.streamError)
		{
			if (error)
				*error = stream.streamError;
			return nil;
		}
		return data;
	}
}

- (CGDataProviderRef)newDataProviderWithPassword:(NSString*)password error:(out NSError**)error
{
	if (![self checkEncryptionAndCompression:error])
		return nil;

	NSData* fileData = [self fileData];
	
	if (self.compressionMethod == ULZZCompressionMethod::stored && _encryptionMode == ULZZEncryptionModeNone)
		// simple data provider that just wraps the data.  Make sure to create a new object since [NSData copy] returns the same object on pre-10.9 systems.
		return CGDataProviderCreateWithCFData((__bridge CFDataRef)[[NSData alloc] initWithBytes:fileData.bytes length:fileData.length]);
	else
		return ULZZDataProvider::create(^
									  {
										  // FIXME: How do we handle the error here?
										  return [self streamForData:fileData withPassword:password error:nil];
									  });
}

- (id<ULZZArchiveEntryWriter>)newWriterCanSkipLocalFile:(BOOL)canSkipLocalFile
{
	return [[ULZZOldArchiveEntryWriter alloc] initWithCentralFileHeader:_centralFileHeader
												  localFileHeader:_localFileHeader
											  shouldSkipLocalFile:canSkipLocalFile];
}

@end

//
//  ULZZError.h
//  ZipZap
//
//  Created by Glen Low on 25/01/13.
//  Copyright (c) 2013, Pixelglow Software. All rights reserved.
//

//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
//  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
//  OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
//  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
//  THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Foundation/Foundation.h>

/**
 * The domain of ZipZap errors.
 */
extern NSString* const ULZZErrorDomain;

/**
 * The index of the erroneous entry.
 */
extern NSString* const ULZZEntryIndexKey;

typedef NS_ENUM(NSInteger, ULZZErrorCode)
{
	/**
	 * Cannot open an archive for reading.
	 */
	ULZZOpenReadErrorCode,
	
	/**
	 * Cannot read the end of central directory.
	 */
	ULZZEndOfCentralDirectoryReadErrorCode,
	
	/**
	 * Cannot read a central file header.
	 */
	ULZZCentralFileHeaderReadErrorCode,
	
	/**
	 * Cannot read a local file.
	 */
	ULZZLocalFileReadErrorCode,
	
	/**
	 * Cannot open an archive for writing.
	 */
	ULZZOpenWriteErrorCode,
	
	/**
	 * Cannot write a local file.
	 */
	ULZZLocalFileWriteErrorCode,
	
	/**
	 * Cannot write a central file header.
	 */
	ULZZCentralFileHeaderWriteErrorCode,
	
	/**
	 * Cannot write the end of central directory.
	 */
	ULZZEndOfCentralDirectoryWriteErrorCode,
    
	/**
	 * Cannot replace the zip file after writing.
	 */
	ULZZReplaceWriteErrorCode,
	
	/**
	 * The compression used is currently unsupported.
	 */
	ULZZUnsupportedCompressionMethod,
    
	/**
	 * The encryption used is currently unsupported.
	 */
	ULZZUnsupportedEncryptionMethod,
    
	/**
	 * An invalid CRC checksum has been encountered.
	 */
	ULZZInvalidCRChecksum,
    
	/**
	 * The wrong key was passed in.
	 */
	ULZZWrongPassword,
	
	/**
	 * The data, stream or data consumer block failed but did not set the error.
	 * This will be set on the underlying error of the local file write.
	 */
	ULZZBlockFailedWithoutError
};

static inline BOOL ULZZRaiseErrorNo(NSError** error, ULZZErrorCode errorCode, NSDictionary* userInfo)
{
	if (error)
		*error = [NSError errorWithDomain:ULZZErrorDomain
									 code:errorCode
								 userInfo:userInfo];
	return NO;
}

static inline id ULZZRaiseErrorNil(NSError** error, ULZZErrorCode errorCode, NSDictionary* userInfo)
{
	if (error)
		*error = [NSError errorWithDomain:ULZZErrorDomain
									 code:errorCode
								 userInfo:userInfo];
	return nil;
}


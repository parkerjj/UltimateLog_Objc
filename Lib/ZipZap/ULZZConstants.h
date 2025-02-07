//
//  ULZZConstants.h
//  ZipZap
//
//  Created by Daniel Cohen Gindi on 29/12/13.
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

typedef NS_ENUM(NSInteger, ULZZEncryptionMode)
{
	/**
	 * No encryption.
	 */
	ULZZEncryptionModeNone,

	/**
	 * Standard PKZIP encryption.
	 */
	ULZZEncryptionModeStandard,

	/**
	 * Strong PKZIP encryption. Currently not supported.
	 */
	ULZZEncryptionModeStrong,

	/**
	 * WinZip encryption using AES.
	 */
	ULZZEncryptionModeWinZipAES
};

typedef NS_ENUM(uint8_t, ULZZAESEncryptionStrength)
{
	/**
	 * Use 128-bit AES for encryption.
	 */
	ULZZAESEncryptionStrength128 = 0x01,

	/**
	 * Use 192-bit AES for encryption.
	 */
	ULZZAESEncryptionStrength192 = 0x02,

	/**
	 * Use 256-bit AES for encryption.
	 */
	ULZZAESEncryptionStrength256 = 0x03
};

/**
 * An NSNumber object that determines whether to create the archive file if it is missing. Creation occurs during -[ULZZArchive updateEntries:error:]. Default is @NO.
 */
extern NSString* const ULZZOpenOptionsCreateIfMissingKey;

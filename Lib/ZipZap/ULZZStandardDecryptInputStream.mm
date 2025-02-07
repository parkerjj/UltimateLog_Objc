//
//  ULZZStandardDecryptInputStream.mm
//  ZipZap
//
//  Created by Daniel Cohen Gindi on 29/12/13.
//  Copyright (c) 2013, Pixelglow Software. All rights reserved.
//

#import "ULZZError.h"
#import "ULZZStandardDecryptInputStream.h"
#import "ULZZStandardCryptoEngine.h"

@implementation ULZZStandardDecryptInputStream
{
	NSInputStream* _upstream;
	ULZZStandardCryptoEngine _crypto;
}

- (instancetype)initWithStream:(NSInputStream*)upstream
					  password:(NSString*)password
						header:(uint8_t*)header
						 check:(uint16_t)check
					   version:(uint8_t)version
						 error:(out NSError**)error
{
	if ((self = [super init]))
	{
		_upstream = upstream;

		_crypto.initKeys((unsigned char*)password.UTF8String);

		bool checkTwoBytes = version < 20;

		for (int i = 0; i < 12; i++)
		{
			uint8_t result = header[i] ^ _crypto.decryptByte();
			_crypto.updateKeys(result);

			// check against decryption result
			BOOL fail = NO;
			switch (i)
			{
				case 10:
					if (checkTwoBytes)
						// check low byte
						fail = result != (check & 0xFF);
					break;
				case 11:
					// check high byte
					fail = result != (check >> 8);
					break;
			}
			if (fail)
				return ULZZRaiseErrorNil(error, ULZZWrongPassword, @{});
		}
	}
	return self;
}

- (NSStreamStatus)streamStatus
{
	return _upstream.streamStatus;
}

- (NSError*)streamError
{
	return _upstream.streamError;
}

- (void)open
{
	[_upstream open];
}

- (void)close
{
	[_upstream close];
}

- (NSInteger)read:(uint8_t*)buffer maxLength:(NSUInteger)len
{
	NSInteger bytesRead = [_upstream read:buffer maxLength:len];
	
	for (NSInteger i = 0; i < bytesRead; i++)
	{
		unsigned char val = buffer[i] & 0xff;
		val = (val ^ _crypto.decryptByte()) & 0xff;
		_crypto.updateKeys(val);
		buffer[i] = val;
	}
	
	return bytesRead;
}

- (BOOL)getBuffer:(uint8_t**)buffer length:(NSUInteger*)len
{
	return NO;
}

- (BOOL)hasBytesAvailable
{
	return YES;
}

@end

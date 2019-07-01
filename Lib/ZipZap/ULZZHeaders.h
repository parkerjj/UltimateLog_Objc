//
//  ULZZHeaders.h
//  ZipZap
//
//  Created by Glen Low on 6/10/12.
//  Copyright (c) 2012, Pixelglow Software. All rights reserved.
//

#include <stdint.h>
#include "ULZZConstants.h"

enum class ULZZCompressionMethod : uint16_t
{
	stored = 0,
	deflated = 8
};

enum class ULZZFileAttributeCompatibility : uint8_t
{
	msdos = 0,
	unix = 3,
    ntfs = 10
};

enum class ULZZMSDOSAttributes : uint8_t
{
	readonly = 1 << 0,
	hidden = 1 << 1,
    system = 1 << 2,
	volume = 1 << 3,
	subdirectory = 1 << 4,
	archive = 1 << 5
};

enum class ULZZGeneralPurposeBitFlag: uint16_t
{
	none = 0,
	encrypted = 1 << 0,
	normalCompression = 0,
	maximumCompression = 1 << 1,
	fastCompression = 1 << 2,
	superFastCompression = (1 << 1) | (1 << 2),
	sizeInDataDescriptor = 1 << 3,
	encryptionStrong = 1 << 6,
	languageEncoding = 1 << 11
};

inline ULZZGeneralPurposeBitFlag operator|(ULZZGeneralPurposeBitFlag lhs, ULZZGeneralPurposeBitFlag rhs)
{
	return static_cast<ULZZGeneralPurposeBitFlag>(static_cast<uint16_t>(lhs) | static_cast<uint16_t>(rhs));
}

inline ULZZGeneralPurposeBitFlag operator&(ULZZGeneralPurposeBitFlag lhs, ULZZGeneralPurposeBitFlag rhs)
{
	return static_cast<ULZZGeneralPurposeBitFlag>(static_cast<uint16_t>(lhs) & static_cast<uint16_t>(rhs));
}

#pragma pack(1)

struct ULZZExtraField
{
	uint16_t headerID;
	uint16_t dataSize;
	
    ULZZExtraField *nextExtraField()
    {
		return reinterpret_cast<ULZZExtraField*>(((uint8_t*)this) + sizeof(ULZZExtraField) + dataSize);
    }
};

struct ULZZWinZipAESExtraField: public ULZZExtraField
{
	uint16_t versionNumber;
	uint8_t vendorId[2]; // For WinZip, should always be AE
    ULZZAESEncryptionStrength encryptionStrength;
    ULZZCompressionMethod compressionMethod;
    
	static const uint16_t head = 0x9901;
    
	static const uint16_t version_AE1 = 0x0001;
	static const uint16_t version_AE2 = 0x0002;
};

inline size_t getSaltLength(ULZZAESEncryptionStrength encryptionStrength)
{
	switch (encryptionStrength)
	{
		case ULZZAESEncryptionStrength128:
			return 8;
		case ULZZAESEncryptionStrength192:
			return 12;
		case ULZZAESEncryptionStrength256:
			return 16;
		default:
			return -1;
	}
}

inline size_t getKeyLength(ULZZAESEncryptionStrength encryptionStrength)
{
	switch (encryptionStrength)
	{
		case ULZZAESEncryptionStrength128:
			return 16;
		case ULZZAESEncryptionStrength192:
			return 24;
		case ULZZAESEncryptionStrength256:
			return 32;
		default:
			return -1;
	}
}

inline size_t getMacLength(ULZZAESEncryptionStrength encryptionStrength)
{
	switch (encryptionStrength)
	{
		case ULZZAESEncryptionStrength128:
			return 16;
		case ULZZAESEncryptionStrength192:
			return 24;
		case ULZZAESEncryptionStrength256:
			return 32;
		default:
			return -1;
	}
}


struct ULZZCentralFileHeader
{
	uint32_t signature;
	uint8_t versionMadeBy;
	ULZZFileAttributeCompatibility fileAttributeCompatibility;
	uint16_t versionNeededToExtract;
	ULZZGeneralPurposeBitFlag generalPurposeBitFlag;
	ULZZCompressionMethod compressionMethod;
	uint16_t lastModFileTime;
	uint16_t lastModFileDate;
	uint32_t crc32;
	uint32_t compressedSize;
	uint32_t uncompressedSize;
	uint16_t fileNameLength;
	uint16_t extraFieldLength;
	uint16_t fileCommentLength;
	uint16_t diskNumberStart;
	uint16_t internalFileAttributes;
	uint32_t externalFileAttributes;
	uint32_t relativeOffsetOfLocalHeader;
	
	static const uint32_t sign = 0x02014b50;
	
	uint8_t* fileName()
	{
		return reinterpret_cast<uint8_t*>(this) + sizeof(*this);
	}
	
	ULZZExtraField* firstExtraField()
	{
		return reinterpret_cast<ULZZExtraField*>(fileName() + fileNameLength);
	}
	
	ULZZExtraField* lastExtraField()
	{
		return reinterpret_cast<ULZZExtraField*>(reinterpret_cast<uint8_t*>(firstExtraField()) + extraFieldLength);
	}
	
	uint8_t* fileComment()
	{
		return reinterpret_cast<uint8_t*>(lastExtraField());
	}
			
	ULZZCentralFileHeader* nextCentralFileHeader()
	{
		return reinterpret_cast<ULZZCentralFileHeader*>(fileComment() + fileCommentLength);
	}
	
	template <typename T> T* extraField()
	{
		for (auto nextField = firstExtraField(), lastField = lastExtraField(); nextField < lastField; nextField = nextField->nextExtraField())
			if (nextField->headerID == T::head)
				// ASSUME: T is a subclass of ULZZExtraField
				return static_cast<T*>(nextField);
		return NULL;
	}
};

struct ULZZDataDescriptor
{
	uint32_t signature;
	uint32_t crc32;
	uint32_t compressedSize;
	uint32_t uncompressedSize;

	static const uint32_t sign = 0x08074b50;
};

struct ULZZLocalFileHeader
{
	uint32_t signature;
	uint16_t versionNeededToExtract;
	ULZZGeneralPurposeBitFlag generalPurposeBitFlag;
	ULZZCompressionMethod compressionMethod;
	uint16_t lastModFileTime;
	uint16_t lastModFileDate;
	uint32_t crc32;
	uint32_t compressedSize;
	uint32_t uncompressedSize;
	uint16_t fileNameLength;
	uint16_t extraFieldLength;
	
	static const uint32_t sign = 0x04034b50;
	
	uint8_t* fileName()
	{
		return reinterpret_cast<uint8_t*>(this) + sizeof(*this);
	}
	
	ULZZExtraField* firstExtraField()
	{
		return reinterpret_cast<ULZZExtraField*>(fileName() + fileNameLength);
	}
	
	ULZZExtraField* lastExtraField()
	{
		return reinterpret_cast<ULZZExtraField*>(reinterpret_cast<uint8_t*>(firstExtraField()) + extraFieldLength);
	}
	
	uint8_t* fileData()
	{
		return reinterpret_cast<uint8_t*>(lastExtraField());
	}
		
	ULZZDataDescriptor* dataDescriptor(uint32_t compressedSize)
	{
		return reinterpret_cast<ULZZDataDescriptor*>(fileData() + compressedSize);
	}
	
	ULZZLocalFileHeader* nextLocalFileHeader(uint32_t compressedSize)
	{
		return reinterpret_cast<ULZZLocalFileHeader*>(fileData()
													+ compressedSize
													+ ((generalPurposeBitFlag & ULZZGeneralPurposeBitFlag::sizeInDataDescriptor) == ULZZGeneralPurposeBitFlag::none ? 0 : sizeof(ULZZDataDescriptor)));
	}
	
	template <typename T> T* extraField()
	{
		for (auto nextField = firstExtraField(), lastField = lastExtraField(); nextField < lastField; nextField = nextField->nextExtraField())
			if (nextField->headerID == T::head)
				// ASSUME: T is a subclass of ULZZExtraField
				return static_cast<T*>(nextField);
		return NULL;
	}
};

struct ULZZEndOfCentralDirectory
{
	uint32_t signature;
	uint16_t numberOfThisDisk;
	uint16_t numberOfTheDiskWithTheStartOfTheCentralDirectory;
	uint16_t totalNumberOfEntriesInTheCentralDirectoryOnThisDisk;
	uint16_t totalNumberOfEntriesInTheCentralDirectory;
	uint32_t sizeOfTheCentralDirectory;
	uint32_t offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber;
	uint16_t zipFileCommentLength;
	
	static const uint32_t sign = 0x06054b50;
};

#pragma pack()


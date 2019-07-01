//
//  ULZZScopeGuard.h
//  ZipZap
//
//  Created by Glen Low on 30/12/13.
//  Copyright (c) 2013, Pixelglow Software. All rights reserved.
//
//

class ULZZScopeGuard
{
public:
	ULZZScopeGuard(void(^exit)()): _exit(exit)
	{
	}
	
	~ULZZScopeGuard()
	{
		_exit();
	}

private:
	void(^_exit)();
};

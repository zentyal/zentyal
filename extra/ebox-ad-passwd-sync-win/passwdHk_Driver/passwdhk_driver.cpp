
/********************************************************************
** This file is part of 'AcctSync' package.
**
**  AcctSync is free software; you can redistribute it and/or modify
**  it under the terms of the Lesser GNU General Public License as 
**  published by the Free Software Foundation; either version 2 
**  of the License, or (at your option) any later version.
**
**  AcctSync is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  Lesser GNU General Public License for more details.
**
**  You should have received a copy of the Lesser GNU General Public
**  License along with AcctSync; if not, write to the 
**	Free Software Foundation, Inc.,
**	59 Temple Place, Suite 330, 
**	Boston, MA  02111-1307  
**	USA
**
** +AcctSync was originally Written by.
**  Kervin Pierre
**  Information Technology Department
**  Florida Tech
**  MAR, 2002
**
** +Modified by.
**
** Redistributed under the terms of the LGPL
** license.  See LICENSE.txt file included in
** this package for details.
**
********************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <windows.h>
#include <ntsecapi.h>

typedef NTSTATUS (*PASSWORDCHANGENOTIFYTYPE)(PUNICODE_STRING, ULONG, PUNICODE_STRING);
typedef BOOL (*PASSWORDFILTERTYPE)(PUNICODE_STRING, PUNICODE_STRING, PUNICODE_STRING, BOOL);
typedef BOOL (*INITIALIZECHANGENOTIFYTYPE)(void);

PUNICODE_STRING new_punicode(PWSTR s)
{
	PUNICODE_STRING ret = (PUNICODE_STRING)calloc(1, sizeof(LSA_UNICODE_STRING));

	ret->Length = wcslen(s)*2;
	ret->MaximumLength = ret->Length;
	ret->Buffer = _wcsdup(s);

	return ret;
}

int __cdecl main(int argc, char* argv[])
{
	
	PASSWORDCHANGENOTIFYTYPE	passwordchangenotify;
	PASSWORDFILTERTYPE			passwordfilter;
	INITIALIZECHANGENOTIFYTYPE	initializechangenotify;
	HINSTANCE	hDLL;
	BOOL		retVal;
	char		*dll_filename;

	if( argv[1] == NULL || strlen(argv[1]) < 4 )
		dll_filename = strdup("passwdhk.dll");
	else dll_filename = strdup(argv[1]);

	printf("Attempting to load \"%s\"\n", dll_filename);
	hDLL = LoadLibrary(argv[1]);
	if (hDLL != NULL)
	{
		passwordchangenotify = (PASSWORDCHANGENOTIFYTYPE)GetProcAddress(hDLL, "PasswordChangeNotify");
		if (!passwordchangenotify)
		{
			printf("ERROR: could not load PasswordChangeNotify function.\n");
			return 1;
		}

		passwordfilter = (PASSWORDFILTERTYPE)GetProcAddress(hDLL, "PasswordFilter");
		if (!passwordfilter)
		{
			printf("ERROR: could not load PasswordFilter function.\n");
			return 1;
		}

		initializechangenotify = (INITIALIZECHANGENOTIFYTYPE)GetProcAddress(hDLL, "InitializeChangeNotify");
		if (!initializechangenotify)
		{
			printf("ERROR: could not load InitializeChangeNotify function.\n");
			return 1;
		}
	}
	else
	{
		printf("ERROR: could not load library \"%s\"\n", dll_filename);
		return 1;
	}

	printf("\nCalling InitialChangeNotify\n===========================================\n\n");
	retVal = initializechangenotify();
	printf("function returned %d\n\n===========================================\n\n", retVal);

	printf("\nCalling PasswordFilter\n===========================================\n\n");
	retVal = passwordfilter(new_punicode(L"kervin"), 
		new_punicode(L"Kervin Pierre"),	new_punicode(L"s3cr3t!!-p@66wd"), FALSE);
	printf("function returned %d\n\n===========================================\n\n", retVal);

	printf("\nCalling PasswordChangeNotify\n===========================================\n\n");
	passwordchangenotify(new_punicode(L"kervin"), 1234, new_punicode(L"s3cr3t!!-p@66wd"));
	printf("\n===========================================\n\n");

	FreeLibrary( hDLL );
	return 0;
}


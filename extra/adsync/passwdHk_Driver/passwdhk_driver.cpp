
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
**  Brian Clayton
**  Information Technology Services
**  Clark University
**  APR, 2008
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
#include <tchar.h>
#include <process.h>

#ifdef UNICODE
#define new_punicode new_punicode_w
#else
#define new_punicode new_punicode_a
#endif

typedef NTSTATUS (NTAPI *PASSWORDCHANGENOTIFYTYPE)(PUNICODE_STRING, ULONG, PUNICODE_STRING);
typedef BOOL (NTAPI *PASSWORDFILTERTYPE)(PUNICODE_STRING, PUNICODE_STRING, PUNICODE_STRING, BOOL);
typedef BOOL (NTAPI *INITIALIZECHANGENOTIFYTYPE)(void);

PASSWORDCHANGENOTIFYTYPE PasswordChangeNotify;
PASSWORDFILTERTYPE PasswordFilter;
INITIALIZECHANGENOTIFYTYPE InitializeChangeNotify;
HANDLE mutex;
int threadCount;

PUNICODE_STRING new_punicode_w(PWSTR s)
{
	PUNICODE_STRING ret = (PUNICODE_STRING)calloc(1, sizeof(LSA_UNICODE_STRING));
	ret->Length = (USHORT)wcslen(s) * sizeof(WCHAR);
	ret->MaximumLength = ret->Length;
	ret->Buffer = _wcsdup(s);

	return ret;
}

PUNICODE_STRING new_punicode_a(PSTR s)
{
	int size;
	PWSTR s2;
	PUNICODE_STRING np;
	size = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
	s2 = (PWSTR)calloc(size, sizeof(WCHAR));
	MultiByteToWideChar(CP_UTF8, 0, s, -1, s2, size);
	np = new_punicode_w(s2);
	free(s2);
	return np;
}

void pshk_test(TCHAR **argv)
{
	PUNICODE_STRING username;
	PUNICODE_STRING password;
	PUNICODE_STRING fullName;
	ULONG rid;
	BOOL retVal;
	int threadNum;

	username = new_punicode(argv[0]);
	password = new_punicode(argv[1]);
	fullName = new_punicode(argv[2]);
	rid = _tcstoul(argv[3], NULL, 10);

	WaitForSingleObject(mutex, INFINITE);
	threadNum = threadCount++;
	ReleaseMutex(mutex);

	_tprintf(_T("\nThread %d calling PasswordFilter\n"), threadNum);
	retVal = PasswordFilter(username, fullName, password, FALSE);
	_tprintf(_T("\nThread %d PasswordFilter returned %d\n"), threadNum, retVal);

	_tprintf(_T("\nThread %d calling PasswordChangeNotify\n"), threadNum);
	PasswordChangeNotify(username, rid, password);
	_tprintf(_T("\nThread %d PasswordChangeNotify complete\n"), threadNum);
	free(username);
	free(password);
	free(fullName);
}

unsigned __stdcall pshk_thread(void *args)
{
	pshk_test((TCHAR **)args);
	_endthread();
	return 0;
}

int _tmain(int argc, TCHAR* argv[])
{
	
	HINSTANCE hDLL;
	BOOL retVal;
	TCHAR *dll_filename = _T("passwdhk.dll");
	HANDLE thread;

	if (argc < 5) {
		_tprintf(_T("Usage: %s username password fullname relativeid [username2 password2 fullname2 relativeid2]\n"), argv[0]);
		return 1;
	}
	
	_tprintf(_T("Attempting to load \"%s\"\n"), dll_filename);
	hDLL = LoadLibrary(dll_filename);
	if (hDLL != NULL) {
		PasswordChangeNotify = (PASSWORDCHANGENOTIFYTYPE)GetProcAddress(hDLL, "PasswordChangeNotify");
		if (!PasswordChangeNotify) {
			_tprintf(_T("ERROR: could not load PasswordChangeNotify function.\n"));
			return 1;
		}

		PasswordFilter = (PASSWORDFILTERTYPE)GetProcAddress(hDLL, "PasswordFilter");
		if (!PasswordFilter) {
			_tprintf(_T("ERROR: could not load PasswordFilter function.\n"));
			return 1;
		}

		InitializeChangeNotify = (INITIALIZECHANGENOTIFYTYPE)GetProcAddress(hDLL, "InitializeChangeNotify");
		if (!InitializeChangeNotify) {
			_tprintf(_T("ERROR: could not load InitializeChangeNotify function.\n"));
			return 1;
		}
	} else {
		_tprintf(_T("ERROR: could not load library \"%s\"\n"), dll_filename);
		return 1;
	}

	_tprintf(_T("\nCalling InitialChangeNotify\n"));
	retVal = InitializeChangeNotify();
	_tprintf(_T("\nfunction returned %d\n"), retVal);

	threadCount = 0;
	mutex = CreateMutex(NULL, FALSE, NULL);
	if (argc > 8)
		thread = (HANDLE)_beginthreadex(NULL, 0, pshk_thread, (void *)&argv[5], 0, NULL);

	pshk_test(&argv[1]);

	if (argc > 8) {
		WaitForSingleObject(thread, INFINITE);
		CloseHandle(thread);
	}

	CloseHandle(mutex);

	FreeLibrary(hDLL);
	return 0;
}


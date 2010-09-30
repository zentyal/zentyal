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
**  MAR, 2008
**
** Redistributed under the terms of the LGPL
** license.  See LICENSE.txt file included in
** this package for details.
**
********************************************************************/


#include "passwdHk.h"

extern pshkConfigStruct pshk_config;

HANDLE pshk_log_open()
{
	HANDLE h;
	if (pshk_config.logLevel < 1)
		return INVALID_HANDLE_VALUE;

	h = CreateFile(pshk_config.logFile, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS, FILE_FLAG_WRITE_THROUGH, NULL);
	if (h != INVALID_HANDLE_VALUE)
		SetFilePointer(h, 0, 0, FILE_END);
	return h;
}

void pshk_log_close(HANDLE h)
{
	BOOL replace = FALSE;
	DWORD dwBytesRead, dwBytesWritten;
	HANDLE hTempFile;
	TCHAR tmppath[MAX_PATH];
	TCHAR tmpfile[MAX_PATH];
	TCHAR bakfile[MAX_PATH];
	LARGE_INTEGER fileSize;
	char buffer[4096];

	if (pshk_config.logLevel >= 1) {
		if (GetFileSizeEx(h, &fileSize)) {
			if (pshk_config.maxLogSize > 0 && fileSize.QuadPart >= pshk_config.maxLogSize * 1000) { // Truncate file if it is over max logfile size 
				memset(tmppath, 0, sizeof(tmppath));
				memset(tmpfile, 0, sizeof(tmppath));
				memset(bakfile, 0, sizeof(bakfile));

				// Create a temporary file. 
				if (GetTempPath(MAX_PATH, tmppath) != 0) {
					GetTempFileName(tmppath, _T("bak"), 0, tmpfile);
					hTempFile = CreateFile(tmpfile, GENERIC_READ | GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
					if (hTempFile != INVALID_HANDLE_VALUE) {
 						// Set the file pointer maxLogSize KB from end of log
						SetFilePointer(h, -(long)(pshk_config.maxLogSize * 1000), NULL, FILE_END);
						// Copy to the temp file.
						do {
							if (ReadFile(h, buffer, 4096, &dwBytesRead, NULL))
								WriteFile(hTempFile, buffer, dwBytesRead, &dwBytesWritten, NULL);
						} while (dwBytesRead == 4096);
						CloseHandle(hTempFile);
						replace = TRUE;
					}
				}
			}
		}
		CloseHandle(h);
		if (replace) {
			// Backup and replace logfile with size-limited tmpfile
			_tcsncpy_s(bakfile, MAX_PATH, pshk_config.logFile, MAX_PATH - 4);
			_tcscat_s(bakfile, MAX_PATH, _T(".bak"));
			DeleteFile(bakfile);
			MoveFile(pshk_config.logFile, bakfile);
			MoveFile(tmpfile, pshk_config.logFile);
		}
	}
}

// Unicode version (calls ANSI version)
BOOL pshk_log_write_w(HANDLE h, LPCWSTR s)
{
	BOOL ret = FALSE;
	char *s2;
	int s2len;
	// Get length needed for new buffer
	s2len = WideCharToMultiByte(CP_UTF8, 0, s, -1, NULL, 0, NULL, NULL);
	if (s2len != 0) {
		s2 = (char *)calloc(1, s2len);
		s2len = WideCharToMultiByte(CP_UTF8, 0, s, -1, s2, s2len, NULL, NULL);
		if (s2len != 0)
			ret = pshk_log_write_a(h, s2);
		free(s2);
	}
	return ret;
}

// ANSI version
BOOL pshk_log_write_a(HANDLE h, LPCSTR s)
{
	BOOL ret = TRUE;
	DWORD NumberOfBytesWritten = 0;
	struct tm newtime;
	time_t aclock;
	INT_PTR tmp2len;
	char tmp[26] = "error getting time";
	char *tmp2;

	if (pshk_config.logLevel < 1)
		return TRUE;

	time(&aclock);
	if (localtime_s(&newtime, &aclock) == 0) {
		asctime_s(tmp, 26, &newtime);
		tmp[24] = '\0'; // Get rid of trailing newline
	}
	tmp2len = strlen(tmp) + strlen(s) + 8;
	tmp2 = (char *)calloc(1, tmp2len);
	_snprintf_s(tmp2, tmp2len, tmp2len - 1, "[ %s ] %s\r\n", tmp, s);
	ret = WriteFile(h, (LPCVOID)tmp2, (int)strlen(tmp2), &NumberOfBytesWritten, NULL);
	free(tmp2);

	return ret;
}

#ifdef _DEBUG

void pshk_log_debug_log_w(LPCWSTR s)
{
	char *s2;
	int s2len;
	s2len = WideCharToMultiByte(CP_UTF8, 0, s, -1, NULL, 0, NULL, NULL);
	if (s2len != 0) {
		s2 = (char *)calloc(1, s2len);
		s2len = WideCharToMultiByte(CP_UTF8, 0, s, -1, s2, s2len, NULL, NULL);
		if (s2len != 0)
			pshk_log_debug_log_a(s2);
		free(s2);
	}
}

void pshk_log_debug_log_a(LPCSTR s)
{
	HANDLE	hLogFile;
	DWORD	NumberOfBytesWritten = 0;

	// Open
	hLogFile = CreateFile(_T("c:\\passwdhkdebug.txt"), GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
	SetFilePointer(hLogFile, 0, 0, FILE_END);

	// Write
	WriteFile(hLogFile, (LPCVOID)s, (int)strlen(s), &NumberOfBytesWritten, NULL);

	// Close
	CloseHandle(hLogFile);
}

#endif
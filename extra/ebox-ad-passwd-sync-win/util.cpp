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
**  MAR 2008
**
** Redistributed under the terms of the LGPL
** license.  See LICENSE.txt file included in
** this package for details.
**
********************************************************************/


#include "passwdHk.h"

extern pshkConfigStruct pshk_config;
extern HANDLE hExecProgMutex;

LPTSTR pshk_struct2str()
{
	TCHAR *tmp, *tmp2;
	
	tmp = (TCHAR *)calloc(1, 10 * PSHK_REG_VALUE_MAX_LEN_BYTES);
	tmp2 = _tcsdup(_T("NULL"));

	if (pshk_config.preChangeProg == NULL)
		pshk_config.preChangeProg = tmp2;
	if (pshk_config.preChangeProgArgs == NULL)
		pshk_config.preChangeProgArgs = tmp2;
	if (pshk_config.postChangeProg == NULL)
		pshk_config.postChangeProg = tmp2;
	if (pshk_config.postChangeProgArgs == NULL)
		pshk_config.postChangeProgArgs = tmp2;
	if (pshk_config.logFile == NULL)
		pshk_config.logFile = tmp2;
	if (pshk_config.workingDir == NULL)
		pshk_config.workingDir = tmp2;
	if (pshk_config.environmentStr == NULL)
		pshk_config.environmentStr = tmp2;

	_stprintf_s(tmp, 10 * PSHK_REG_VALUE_MAX_LEN, _T("\r\nvalid: %d\r\npreChangeProg: '%s'\r\npreChangeProgArgs: '%s'\r\npreChangeProgWait: %d\r\npostChangeProg: '%s'\r\npostChangeProgArgs: '%s'\r\npostChangeProgWait: %d\r\nlogFile: '%s'\r\nmaxLogSize: %d\r\nlogLevel: %d\r\nurlencode: %s\r\ndoublequote: %s\r\nenvironmentStr: '%s'\r\nworkingdirectory: '%s'\r\npriority: %d\r\ninheritParentHandles: %s\r\n"), pshk_config.valid, pshk_config.preChangeProg, pshk_config.preChangeProgArgs, pshk_config.preChangeProgWait, pshk_config.postChangeProg, pshk_config.postChangeProgArgs, pshk_config.postChangeProgWait, pshk_config.logFile, pshk_config.maxLogSize, pshk_config.logLevel, pshk_config.urlencode ? _T("true") : _T("false"), pshk_config.doublequote ? _T("true") : _T("false"), pshk_config.environmentStr, pshk_config.workingDir, pshk_config.priority, pshk_config.inheritParentHandles ? _T("true") : _T("false"));

	tmp2 = _tcsdup(tmp);
	free(tmp);

	return tmp2;
}

// Converts a unicode string (UTF-16) to UTF-8, URL encodes it, and converts it back
//
LPWSTR rawurlencode_w(LPWSTR src)
{
	int size;
	char *src2, *ret;
	WCHAR *ret2 = NULL;
	// Get buffer size needed for UTF-8 string
	size = WideCharToMultiByte(CP_UTF8, 0, src, -1, NULL, 0, NULL, NULL);
	if (size != 0) {
		// Allocate and convert
		src2 = (char *)calloc(size, 1);
		size = WideCharToMultiByte(CP_UTF8, 0, src, -1, src2, size, NULL, NULL);
		if (size != 0) {
			// URL encode
			ret = rawurlencode_a(src2);
			// Get required buffer size
			size = MultiByteToWideChar(CP_UTF8, 0, ret, -1, NULL, 0);
			if (size != 0) {
				// Allocate and convert
				ret2 = (WCHAR *)calloc(size, sizeof(WCHAR));
				size = MultiByteToWideChar(CP_UTF8, 0, ret, -1, ret2, size);
			}
		}
		free(src2);
	}
	return ret2;
}

// urlencodes a string according to the PHP function rawurlencode
//
// From the PHP manual...
//      Returns a string in which all non-alphanumeric characters
//      except -_. have been replaced with a percent (%) sign 
//      followed by two hex digits.
//
LPSTR rawurlencode_a(LPSTR src)
{
	LPSTR res, res2;
	unsigned int i, j = 0;
	UINT_PTR srclen;
	unsigned char c;

	if (src == NULL || (srclen = strlen(src)) == 0)
		return NULL;

	res = (LPSTR)calloc(srclen + 1, 3);
	for (i = 0; i < srclen; i++) {
		c = (unsigned char)src[i]; // Needs to be treated as unsigned for UTF-8
		if (isalnum(c) || c == '-' || c == '_' || c == '.')
			res[j++] = c;
		else {
			_snprintf_s(&res[j], 4, 3, "%%%2x", c);
			j += 3;
		}
	}
	res2 = _strdup(res);
	free(res);

	return res2;
}

// Calls the needed program with supplied user.
//
int pshk_exec_prog(int option, TCHAR *username, TCHAR *password)
{
	TCHAR *lpBuf, *encodedStr = NULL, *prog, *args;
	int wait;
	int ret = PSHK_SUCCESS;
	unsigned i, j, k;
	DWORD NumberOfBytesWritten = 0;
	DWORD_PTR HeapSize, HeapSizeBytes;
	DWORD exitCode = 0;
	DWORD progRet;
	STARTUPINFO si;
    PROCESS_INFORMATION pi;
	SECURITY_ATTRIBUTES sa;
	HANDLE h;

	if (option == PSHK_PRE_CHANGE) {
		prog = pshk_config.preChangeProg;
		args = pshk_config.preChangeProgArgs;
		wait = pshk_config.preChangeProgWait;
	} else if (option == PSHK_POST_CHANGE) {
		prog = pshk_config.postChangeProg;
		args = pshk_config.postChangeProgArgs;
		wait = pshk_config.postChangeProgWait;
	} else // Unknown option
		return PSHK_FAILURE;

	// If no command is specified, say that we succeeded
	if (_tcslen(prog) == 0 && _tcslen(args) == 0)
		return PSHK_SUCCESS;

	// Get mutex - unfortunately, this whole section must be mutually exclusive so that the log doesn't get garbled by overlapping writes from multiple threads
	// ** Must be released before return!
	WaitForSingleObject(hExecProgMutex, INFINITE);

	// Open log
	h = pshk_log_open();

	if (pshk_config.urlencode == TRUE) {
		// URL encode password
		encodedStr = rawurlencode(password);
		if (encodedStr == NULL)
			pshk_log_write(h, _T("Error URL encoding password"));
		else
			password = encodedStr;
	}
	if (pshk_config.doublequote == TRUE) {
		// Escape double-quotes
		encodedStr = (TCHAR *)calloc(_tcslen(password) * 2 + 3, sizeof(TCHAR));
		j = 0;
		encodedStr[j++] = _T('"');
		for (i = 0; i < _tcslen(password); i++) {
			if (password[i] == _T('"')) {
				k = i;
				while (k > 0 && password[--k] == '\\') // Any backslash or sequence of backslashes immediately preceding the quote must be escaped too
					encodedStr[j++] = '\\';
				encodedStr[j++] = '\\';
			}
			encodedStr[j++] = password[i];
		}
		k = i;
		while (k > 0 && password[--k] == '\\') // Any backslash or sequence of backslashes immediately preceding the closing quote must be escaped too
			encodedStr[j++] = '\\';
		encodedStr[j] = _T('"');
		password = _tcsdup(encodedStr);
		free(encodedStr);
	}

	// Once password is encoded (if specified), calculate needed buffer size
	HeapSize = _tcslen(username) + _tcslen(password) + _tcslen(prog) + _tcslen(args) + 32;
	HeapSizeBytes = HeapSize * sizeof(TCHAR);
	lpBuf = (TCHAR *)calloc(1, HeapSizeBytes);

	SecureZeroMemory(&si, sizeof(si));
	SecureZeroMemory(&pi, sizeof(pi));
	SecureZeroMemory(&sa, sizeof(sa));

    si.cb = sizeof(si);

	if (pshk_config.inheritParentHandles) {
		si.dwFlags |= STARTF_USESTDHANDLES;
		DuplicateHandle(GetCurrentProcess(), h, GetCurrentProcess(), (LPHANDLE)&(si.hStdOutput), 0, TRUE, DUPLICATE_SAME_ACCESS);
		DuplicateHandle(GetCurrentProcess(), h, GetCurrentProcess(), (LPHANDLE)&(si.hStdError), 0, TRUE, DUPLICATE_SAME_ACCESS);
		sa.nLength = sizeof(SECURITY_ATTRIBUTES);
		sa.bInheritHandle = TRUE;
	}
	
	// Log the commandline if we at DEBUG loglevel or higher
	if (pshk_config.logLevel >= PSHK_LOG_DEBUG) {
		_sntprintf_s(lpBuf, HeapSize, HeapSize - 1, _T("\r\n\"%s\" %s %s %s\r\n"), prog, args, username, pshk_config.logLevel >= PSHK_LOG_ALL ? password : _T("<hidden>"));
		pshk_log_write(h, lpBuf);
		SecureZeroMemory(lpBuf, HeapSizeBytes);
	}
	
	_sntprintf_s(lpBuf, HeapSize, HeapSize - 1, _T("\"%s\" %s %s %s"), prog, args, username, password);

	// Launch external program
	progRet = CreateProcess(prog, lpBuf, pshk_config.inheritParentHandles ? &sa : NULL, NULL, pshk_config.inheritParentHandles ? TRUE : FALSE, pshk_config.processCreateFlags, pshk_config.environment, pshk_config.workingDir, &si, &pi);

	SecureZeroMemory(lpBuf, HeapSizeBytes);
	free(lpBuf);

	// If we fail and we care about printing errors then do it
	if (!progRet) {
		if (pshk_config.logLevel >= PSHK_LOG_ERROR) {
			TCHAR *fm_buf;
			FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, GetLastError(), MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPTSTR)&fm_buf, 0, NULL);
			pshk_log_write(h, fm_buf);
			LocalFree(fm_buf);
		}
		ret = PSHK_FAILURE;
	} else {
		// Wait for the process the alotted time
		progRet = WaitForSingleObject(pi.hProcess, wait);
		if (progRet == WAIT_FAILED && pshk_config.logLevel >= PSHK_LOG_ERROR) {
			pshk_log_write(h, _T("Wait failed for the last process.\n"));
		} else if (progRet == WAIT_TIMEOUT) {
			if ((option == PSHK_PRE_CHANGE && pshk_config.logLevel >= PSHK_LOG_ERROR) || (option == PSHK_POST_CHANGE && pshk_config.logLevel >= PSHK_LOG_DEBUG))
				pshk_log_write(h, _T("Wait timed out for the last process."));
			if (option == PSHK_PRE_CHANGE)
				ret = PSHK_FAILURE;
		}

		if (ret == PSHK_SUCCESS) {
			// If this is a pre-change program, then we care about the 
			// exit code of the process as well.
			if (option == PSHK_PRE_CHANGE) {
				// Return fail if we get an exit code other than 0 or GetExitCodeProcess() fails
				if (GetExitCodeProcess(pi.hProcess, &exitCode) == FALSE) {
					if (pshk_config.logLevel >= PSHK_LOG_ERROR)
						pshk_log_write(h, _T("Error while recieving error code from process."));
					ret = PSHK_FAILURE;
				} else if (exitCode)
					ret = PSHK_FAILURE;
			}
			if (pshk_config.logLevel >= PSHK_LOG_DEBUG)
				pshk_log_write(h, _T("\r\n"));
		}
	}
	CloseHandle(pi.hProcess);
	CloseHandle(pi.hThread);
	if (pshk_config.inheritParentHandles) {
		CloseHandle(si.hStdOutput);
		CloseHandle(si.hStdError);
	}

	// Close log
	pshk_log_close(h);

	// Release mutex
	ReleaseMutex(hExecProgMutex);

	return ret;
}

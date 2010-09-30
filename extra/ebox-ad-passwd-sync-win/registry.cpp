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

// convert "$%%$" to 0
TCHAR *parse_env(TCHAR *str)
{
	TCHAR *ret;
	size_t i, j, slen;
	
	if (str == NULL || (slen = _tcslen(str)) == 0)
		return NULL;
	
	ret = (TCHAR *)calloc(slen + 2, sizeof(TCHAR)); // Two trailing nulls to terminate
	i = 0;
	for (j = 0; j < slen && i < slen; j++) {
		if (str[j] == _T('$') && j < slen - 3 && str[j + 1] == _T('%') && str[j + 2] == _T('%') && str[j + 3] == _T('$')) {
			ret[i] = _T('\0');
			j += 3;
		} else
			ret[i] = str[j];
		i++;
	}
	
	return ret;
}

BOOL read_registry_value(HKEY hKey, LPCTSTR lpValueName, LPBYTE lpData, LPDWORD lpcbData)
{
	*lpcbData = PSHK_REG_VALUE_MAX_LEN_BYTES;
	memset(lpData, 0, *lpcbData);
	return (RegQueryValueEx(hKey, lpValueName, NULL, NULL, lpData, lpcbData) == ERROR_SUCCESS);
}

BOOL string_to_bool(LPTSTR str)
{
	return (!_tcsicmp(str, _T("true")) || !_tcsicmp(str, _T("yes")) || !_tcsicmp(str, _T("on")));
}

pshkConfigStruct pshk_read_registry(void)
{
    HKEY hk;  
    TCHAR szBuf[PSHK_REG_VALUE_MAX_LEN + 1];
	DWORD szBufSize = PSHK_REG_VALUE_MAX_LEN_BYTES;
	pshkConfigStruct ret = {0};
		
	memset(szBuf, 0, sizeof(szBuf));
	
	if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, PSHK_REG_KEY, 0, KEY_QUERY_VALUE, &hk) != ERROR_SUCCESS)
        return ret;

	if (read_registry_value(hk, _T("preChangeProg"), (LPBYTE)szBuf, &szBufSize)) {
		ret.preChangeProg = _tcsdup(szBuf);
		ret.valid = 1;
	}

	if (read_registry_value(hk, _T("preChangeProgArgs"), (LPBYTE)szBuf, &szBufSize))
		ret.preChangeProgArgs = _tcsdup(szBuf);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("preChangeProgWait"), (LPBYTE)szBuf, &szBufSize))
		ret.preChangeProgWait = _tcstol(szBuf, NULL, 10);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("postChangeProg"), (LPBYTE)szBuf, &szBufSize))
		ret.postChangeProg = _tcsdup(szBuf);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("postChangeProgArgs"), (LPBYTE)szBuf, &szBufSize))
		ret.postChangeProgArgs = _tcsdup(szBuf);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("postChangeProgWait"), (LPBYTE)szBuf, &szBufSize))
		ret.postChangeProgWait = _tcstol(szBuf, NULL, 10);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("logfile"), (LPBYTE)szBuf, &szBufSize))
		ret.logFile = _tcsdup(szBuf);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("maxlogsize"), (LPBYTE)szBuf, &szBufSize))
		ret.maxLogSize = _tcstol(szBuf, NULL, 10);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("loglevel"), (LPBYTE)szBuf, &szBufSize))
		ret.logLevel = _tcstol(szBuf, NULL, 10);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("urlencode"), (LPBYTE)szBuf, &szBufSize))
		ret.urlencode = string_to_bool(szBuf);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("doublequote"), (LPBYTE)szBuf, &szBufSize))
		ret.doublequote = string_to_bool(szBuf);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("environment"), (LPBYTE)szBuf, &szBufSize)) {
		ret.environmentStr = _tcsdup(szBuf);
		ret.environment = parse_env(szBuf);
	} else
		ret.valid = 0;
	if (read_registry_value(hk, _T("workingdir"), (LPBYTE)szBuf, &szBufSize))
		ret.workingDir = _tcsdup(szBuf);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("priority"), (LPBYTE)szBuf, &szBufSize))
		ret.priority = _tcstol(szBuf, NULL, 10);
	else
		ret.valid = 0;
	if (read_registry_value(hk, _T("output2log"), (LPBYTE)szBuf, &szBufSize))
		ret.inheritParentHandles = string_to_bool(szBuf);
	else
		ret.valid = 0;

    RegCloseKey(hk);
	
	return ret;
} 
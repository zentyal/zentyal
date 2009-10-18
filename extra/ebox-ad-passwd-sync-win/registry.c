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


#include "passwdHk.h"

char *escape_slashes(char *str)
{
	int count = 0;
	unsigned int i;
	int j=0;
	char *ret;

	for(i=0;i<strlen(str);i++)
		if(str[i]=='\\')
			count++;

	ret = calloc(1, strlen(str)+count+1);

	for(i=0; i<strlen(str); i++)
	{
		if(str[i]=='\\')
			ret[j++]='\\';
		ret[j++]=str[i];
	}

	return ret;
}

/* convert "$%%$" to 0 */
char *parse_env(char *str)
{
	char *tmp, *ret, *rest;

	if( str==NULL || strlen(str)==0 )
		return NULL;

	ret = calloc(1, strlen(str)+2);
	memcpy(ret, str, strlen(str));

	rest = ret;
	while( (tmp = strstr(rest, "$%%$")) != NULL )
	{
		strcpy(&tmp[1], &tmp[4]);
		memset(&str[strlen(rest)-4], 0, 3);
		tmp[0] = 0;
		rest = &tmp[1];
	}

	return ret;
}

pshkConfigStruct pshk_read_registry(void)
{
    HKEY hk;
    CHAR szBuf[PSHK_REG_VALUE_MAX_LEN+1];
	DWORD szBufSize = PSHK_REG_VALUE_MAX_LEN;
	pshkConfigStruct ret = {0};
	DWORD readRetVal;

	memset(szBuf, 0, sizeof(szBuf));

	if( RegOpenKeyEx(HKEY_LOCAL_MACHINE, PSHK_REG_KEY,
		0, KEY_QUERY_VALUE, &hk) != ERROR_SUCCESS )
	{
        return ret;
	}

	/* Get the log level */
	readRetVal
		= RegQueryValueEx( hk,"loglevel", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.logLevel = strtol(szBuf, NULL, 10);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the priority */
	readRetVal
		= RegQueryValueEx( hk,"priority", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.priority = strtol(szBuf, NULL, 10);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the pre-change program wait time */
	readRetVal
		= RegQueryValueEx( hk,"preChangeProgWait", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.preChangeProgWait = strtol(szBuf, NULL, 10);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the post-change program wait time */
	readRetVal
		= RegQueryValueEx( hk,"postChangeProgWait", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.postChangeProgWait = strtol(szBuf, NULL, 10);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the working directory */
	readRetVal = RegQueryValueEx(hk, "workingdir", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.workingDir = escape_slashes(szBuf);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the log file */
	readRetVal = RegQueryValueEx(hk, "logfile", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.logFile = escape_slashes(szBuf);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the max log file size*/
	readRetVal = RegQueryValueEx(hk, "maxlogsize", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.maxLogSize = strtol(szBuf, NULL, 10);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Pre password change program file */
	readRetVal = RegQueryValueEx(hk, "preChangeProg", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.preChangeProg = escape_slashes(szBuf);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Pre password change program args */
	readRetVal = RegQueryValueEx(hk, "preChangeProgArgs", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.preChangeProgArgs = escape_slashes(szBuf);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Post password change program file */
	readRetVal = RegQueryValueEx(hk, "postChangeProg", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.postChangeProg = escape_slashes(szBuf);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Post password change program args */
	readRetVal = RegQueryValueEx(hk, "postChangeProgArgs", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.postChangeProgArgs = escape_slashes(szBuf);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Environment string */
	readRetVal = RegQueryValueEx(hk, "environment", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	ret.environmentStr = strdup(szBuf);
	ret.environment = parse_env(szBuf);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get wether to urlencode the password string */
	readRetVal = RegQueryValueEx(hk, "urlencode", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	if(!_stricmp(szBuf, "true") || \
		!_stricmp(szBuf, "yes") || \
		!_stricmp(szBuf, "on")			)
		ret.urlencode = TRUE;
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get wether to output to logfile */
	readRetVal = RegQueryValueEx(hk, "output2log", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
		return ret;
	if(!_stricmp(szBuf, "true") || \
		!_stricmp(szBuf, "yes") || \
		!_stricmp(szBuf, "on")			)
		ret.inheritParentHandles = TRUE;

    RegCloseKey(hk);

	ret.valid = 1;
	return ret;
}

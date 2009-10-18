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

LPSTR pshk_struct2str( pshkConfigStruct c )
{
	char *tmp, *tmp2;
	
	tmp = calloc(1, 4 * PSHK_REG_VALUE_MAX_LEN );
	tmp2 = strdup("NULL");

	if( c.preChangeProg == NULL )
		c.preChangeProg = tmp2;
	if( c.preChangeProgArgs == NULL )
		c.preChangeProgArgs = tmp2;
	if( c.postChangeProg == NULL )
		c.postChangeProg = tmp2;
	if( c.postChangeProgArgs == NULL )
		c.postChangeProgArgs = tmp2;
	if( c.logFile == NULL )
		c.logFile = tmp2;
	if( c.workingDir == NULL )
		c.workingDir = tmp2;
	if( c.environmentStr == NULL )
		c.environmentStr = tmp2;

	sprintf(tmp,
		"valid = '%d'\r\nlogLevel = '%d'\r\n\
preChangeProg		= '%s'\r\n\
preChangeProgArgs	= '%s'\r\n\
postChangeProg		= '%s'\r\n\
postChangeProgArgs	= '%s'\r\n\
logFile     = '%s'\r\n\
maxLogSize  = '%d'\r\n\
workingdirectory = '%s'\r\n\
priority = '%d'\r\n\
postChangeProgWait = '%d'\r\n\
preChangeProgWait = '%d'\r\n\
environmentStr = '%s'\r\n",
		c.valid, c.logLevel, c.preChangeProg, c.preChangeProgArgs,
		c.postChangeProg, c.postChangeProgArgs ,
		c.logFile, c.maxLogSize, c.workingDir, c.priority,
		c.preChangeProgWait, c.postChangeProgWait, c.environmentStr );

	tmp2 = strdup(tmp);
	free(tmp);

	return tmp2;
}


// urlencodes a string according to the PHP function rawurlencode
//
// From the PHP manual...
//      Returns a string in which all non-alphanumeric characters
//      except -_. have been replaced with a percent (%) sign 
//      followed by two hex digits.
//
LPSTR rawurlencode(LPSTR src)
{
	LPSTR res, res2;
	unsigned int i, j=0;

	if( src == NULL || strlen(src) == 0 )
		return NULL;

	res = calloc(1, strlen(src) * 3 + 1);

	for(i=0;i<strlen(src);i++)
	{
		if(isalnum(src[i]))
		{
			res[j++] = src[i];
			continue;
		}

		switch(src[i])
		{
			case '-':
			case '_':
			case '.': res[j++] = src[i];
				break;
			default: _snprintf(&res[j], 3, "%%%2x", src[i]);
				j+=3;
		}
	}

	res2 = strdup(res);
	free(res);

	return res2;
}

//
// Calls the needed program with supplied user.
//
int pshk_exec_prog(int option, pshkConfigStruct c, char *username, char *password)
{
	char *lpBuf, *urlencodedStr=NULL;
	DWORD NumberOfBytesWritten = 0;
	DWORD HeapSize;
	DWORD exitCode = 0;
	DWORD ret;
	STARTUPINFO si;
    PROCESS_INFORMATION pi;
	SECURITY_ATTRIBUTES sa;
	char *passwordTemp = strdup("<hidden>");

	if( option == PSHK_PRE_CHANGE )
	{
		/* If no command is specified, say that we succeeded */
		if( strlen(c.preChangeProg) == 0 && strlen(c.preChangeProgArgs) == 0 )
			return PSHK_SUCCESS;

		HeapSize = strlen(username)
			+ strlen(password)
			+ strlen(c.preChangeProg)
			+ strlen(c.preChangeProgArgs)
			+ 32;
	}
	else if ( option == PSHK_POST_CHANGE )
	{
		/* If no command is specified, say that we succeeded */
		if( strlen(c.postChangeProg) == 0 && strlen(c.postChangeProgArgs) == 0 )
			return PSHK_SUCCESS;

		HeapSize = strlen(username)
			+ strlen(password)
			+ strlen(c.postChangeProg)
			+ strlen(c.postChangeProgArgs)
			+ 32;
	}
	else /* unknown option */
		return PSHK_FAILURE;

	lpBuf		= calloc(1, HeapSize);

	if(c.urlencode == TRUE)
		urlencodedStr = rawurlencode(password);

	memset( &si, 0, sizeof(si) );
	memset( &pi, 0, sizeof(pi) );
	memset( &sa, 0, sizeof(sa) );

    si.cb = sizeof(si);

	if( c.inheritParentHandles )
	{
		si.dwFlags |= STARTF_USESTDHANDLES;
		si.hStdOutput = c.hChildSTDOUT;
		si.hStdError = c.hChildSTDERR;
		sa.nLength = sizeof(SECURITY_ATTRIBUTES);
		sa.bInheritHandle = TRUE;
	}
	
	if( c.urlencode == TRUE )
	{
		memset(password, 0, strlen(password));
		free(password);
		password = urlencodedStr;
	}

	/* Log the commandline if we at DEBUG loglevel or higher */
	if( c.logLevel >= PSHK_LOG_DEBUG )
	{
		_snprintf(lpBuf,
				HeapSize -1,
				"\r\n\"%s\" %s %s %s\r\n",
				option==PSHK_PRE_CHANGE?c.preChangeProg:c.postChangeProg,
				option==PSHK_PRE_CHANGE?c.preChangeProgArgs:c.postChangeProgArgs,
				username,
				c.logLevel >= PSHK_LOG_ALL?password:passwordTemp
				);	
		pshk_log_write(&c, lpBuf );
		free(passwordTemp);
		memset( lpBuf, 0, HeapSize );
	}
	
	_snprintf(lpBuf,
		HeapSize -1,
		"\"%s\" %s %s %s",
		option==PSHK_PRE_CHANGE?c.preChangeProg:c.postChangeProg,
		option==PSHK_PRE_CHANGE?c.preChangeProgArgs:c.postChangeProgArgs,
		username,
		password
		);

	memset(username, 0, strlen(username));
	memset(password, 0, strlen(password));

	free(username);
	free(password);

	ret = CreateProcess(
		option==PSHK_PRE_CHANGE?c.preChangeProg:c.postChangeProg,
		lpBuf,
		c.inheritParentHandles?&sa:NULL,
		NULL,
		c.inheritParentHandles?TRUE:FALSE,
		c.processCreateFlags,
		c.environment,
		c.workingDir,
		&si,
		&pi
		);

	memset(lpBuf, 0, HeapSize);
	free(lpBuf);

	/* if we fail and we care about printing errors
	** then do it */
	if( ! ret )
	{
		if( c.logLevel >= PSHK_LOG_ERROR )
		{
			char *fm_buf;

			FormatMessage( 
				FORMAT_MESSAGE_ALLOCATE_BUFFER | 
				FORMAT_MESSAGE_FROM_SYSTEM | 
				FORMAT_MESSAGE_IGNORE_INSERTS,
				NULL,
				GetLastError(),
				MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
				(LPTSTR) &fm_buf,
				0,
				NULL );
			
			pshk_log_write( &c, fm_buf );

			CloseHandle( pi.hProcess );
			CloseHandle( pi.hThread );

			LocalFree(fm_buf);
		}

		return PSHK_FAILURE;
	}

	/* Wait for the process the alotted time */
	ret = WaitForSingleObject( pi.hProcess,
		option==PSHK_PRE_CHANGE?c.preChangeProgWait:c.postChangeProgWait );
	if( ret == WAIT_FAILED && c.logLevel >= PSHK_LOG_ERROR )
	{
		pshk_log_write( &c, "Wait failed for the last process.\n" );
	}
	else if( ret == WAIT_TIMEOUT )
	{
		if( ( option==PSHK_PRE_CHANGE && c.logLevel >= PSHK_LOG_ERROR )
			|| ( option==PSHK_POST_CHANGE && c.logLevel >= PSHK_LOG_DEBUG) )
			pshk_log_write( &c, "Wait timed out for the last process.");

		if( option==PSHK_PRE_CHANGE )
		{
			CloseHandle( pi.hProcess );
			CloseHandle( pi.hThread );
			return PSHK_FAILURE;
		}
	}

	/* if this is a pre-change program, then we care about the 
	** exit code of the process as well. */
	if( option==PSHK_PRE_CHANGE ) 
	{
		/* Return fail if we get an exit code other than 0 or
		** GetExitCodeProcess() fails */
		if( GetExitCodeProcess(pi.hProcess, &exitCode)==FALSE )
		{
			if( c.logLevel >= PSHK_LOG_ERROR )
				pshk_log_write( &c, "Error while recieving error code from process.");

			CloseHandle( pi.hProcess );
			CloseHandle( pi.hThread );
			return PSHK_FAILURE;
		}
		else if(exitCode)
		{
			CloseHandle( pi.hProcess );
			CloseHandle( pi.hThread );
			return PSHK_FAILURE;
		}
	}

	if( c.logLevel >= PSHK_LOG_DEBUG )
		pshk_log_write(&c, ""PSHK_BORDER"\r\n");

    CloseHandle( pi.hProcess );
    CloseHandle( pi.hThread );
	return PSHK_SUCCESS;
}

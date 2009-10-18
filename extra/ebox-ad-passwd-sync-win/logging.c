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

BOOL pshk_log_open( pshkConfigStruct *c )
{
	if( c->logLevel < 1 )
		return TRUE;

	c->hLogFile = CreateFile(
			c->logFile,
			GENERIC_READ|GENERIC_WRITE,
			FILE_SHARE_READ|FILE_SHARE_WRITE,
			NULL,
			OPEN_ALWAYS,                
			FILE_FLAG_WRITE_THROUGH, //FILE_ATTRIBUTE_NORMAL,
			NULL
		);

	if( c->hLogFile == INVALID_HANDLE_VALUE )
	{
		return FALSE;
	}
	
	SetFilePointer( c->hLogFile, 0, 0, FILE_END);

	if( c->inheritParentHandles )
	{
		DuplicateHandle(GetCurrentProcess(), c->hLogFile, GetCurrentProcess(), 
			(LPHANDLE)&(c->hChildSTDOUT), 0, TRUE, DUPLICATE_SAME_ACCESS);

		DuplicateHandle(GetCurrentProcess(), c->hLogFile, GetCurrentProcess(), 
			(LPHANDLE)&(c->hChildSTDERR), 0, TRUE, DUPLICATE_SAME_ACCESS);
	}

	return TRUE;
}

BOOL pshk_log_write( pshkConfigStruct *c, LPCSTR s )
{
	BOOL ret;
	DWORD NumberOfBytesWritten = 0;
	struct tm *newtime;
	time_t aclock;
	int i;
	char *tmp, *tmp2;
	DWORD fileSize, dwBytesRead, dwBytesWritten;
	HANDLE hTempFile;
	char tmppath[MAX_PATH];
	char tmpfile[MAX_PATH];
	char bakfile[MAX_PATH];
	char buffer[4096];

	if( c->logLevel < 1 )
		return TRUE;

	time( &aclock );                 
	newtime = localtime( &aclock );  
	tmp = asctime(newtime);
	tmp[strlen(tmp)-1] = 0;

	i = strlen(tmp) + strlen(s) + 8;
	tmp2 = calloc(1, i);
	_snprintf(tmp2, i-1, "[ %s ] %s\r\n", tmp, s);

	//Get the logfile's size
	fileSize = GetFileSize(c->hLogFile, NULL);
	if( fileSize == INVALID_FILE_SIZE )
		return FALSE;
	
	//Truncate file if it is over max logfile size
	if( c->maxLogSize > 0 && 
		fileSize+strlen(tmp2)+1 >= c->maxLogSize*1000 )
	{
		memset(tmppath, 0, sizeof(tmppath));
		memset(tmpfile, 0, sizeof(tmppath));
		memset(bakfile, 0, sizeof(bakfile));

		// Create a temporary file. 
		if( GetTempPath(sizeof(tmppath), tmppath)==0 )
			return FALSE;

		GetTempFileName(tmppath, // dir. for temp. files 
			"bak",                // temp. file name prefix 
			0,                    // create unique name 
			tmpfile);          // buffer for name 

		hTempFile = CreateFile(tmpfile,  // file name 
			GENERIC_READ | GENERIC_WRITE, // open for read/write 
			0,                            // do not share 
			NULL,                         // no security 
			CREATE_ALWAYS,                // overwrite existing file
			FILE_ATTRIBUTE_NORMAL,        // normal file 
			NULL);                        // no attr. template 

		if (hTempFile == INVALID_HANDLE_VALUE) 
			return FALSE; 
 
		//Set the file pointer to 75% of the full log file.
		SetFilePointer( c->hLogFile, (int)(75*(fileSize/100)), NULL, FILE_BEGIN);
		//Copy to the temp file.
		do 
		{
			if (ReadFile(c->hLogFile, buffer, 4096, 
				&dwBytesRead, NULL)) 
			{ 
				WriteFile(hTempFile, buffer, dwBytesRead, 
					&dwBytesWritten, NULL); 
			} 
		} while (dwBytesRead == 4096); 
 
		
		// Close both files. 
		CloseHandle(c->hLogFile); 
		CloseHandle(hTempFile); 

		//Replace file
		strncpy(bakfile, c->logFile, MAX_PATH-4);
		strcat(bakfile, ".bak");

		DeleteFile(bakfile);
		MoveFile(c->logFile, bakfile);
		MoveFile(tmpfile, c->logFile);
	
		//Open the logfile
		pshk_log_open(c);
	}

	ret = WriteFile( c->hLogFile,         
		(LPCVOID) tmp2,                
		(strlen(tmp2)),
		&NumberOfBytesWritten,
		NULL );

	free(tmp2);

	return ret;
}

#ifdef _DEBUG

void pshk_log_debug_log( LPCSTR s)
{
	HANDLE	hLogFile;
	DWORD	NumberOfBytesWritten = 0;

	/* Open */
	hLogFile = CreateFile(
			"d:\\loglog.txt",
			GENERIC_WRITE,
			FILE_SHARE_READ,
			NULL,
			OPEN_ALWAYS,                
			FILE_ATTRIBUTE_NORMAL,
			NULL
		);

	SetFilePointer( hLogFile, 0, 0, FILE_END);

	/* Write */
	WriteFile( hLogFile,         
		(LPCVOID) s,                
		(strlen(s)),
		&NumberOfBytesWritten,
		NULL );

	/* Close */
	CloseHandle( hLogFile );
}

#endif
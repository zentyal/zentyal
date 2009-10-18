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

#ifndef STATUS_SUCCESS
#define STATUS_SUCCESS  ((NTSTATUS)0x00000000L)
#endif

/* holds all the persistant context information
** Due to the nature of the LSA, this is basically
** a read only structure */
static pshkConfigStruct pshk_config;

/* This is the post-password change function
** The password change has been done */
NTSTATUS NTAPI PasswordChangeNotify( PUNICODE_STRING username, ULONG relativeid, PUNICODE_STRING password )
{
	char *usernameStr, *passwordStr;

	usernameStr	= calloc(1, (username->Length/2)+1);
	passwordStr	= calloc(1, (password->Length/2)+1);

	wcstombs(usernameStr, username->Buffer, (username->Length/2));
	wcstombs(passwordStr, password->Buffer, (password->Length/2));

	pshk_exec_prog(PSHK_POST_CHANGE, pshk_config, usernameStr, passwordStr);

	return STATUS_SUCCESS;
}


/* This is the pre-password change function
** A password change has been requested */
BOOL NTAPI PasswordFilter( PUNICODE_STRING username, PUNICODE_STRING FullName, PUNICODE_STRING password, BOOL SetOperation )
{
	int retVal;
	char *usernameStr, *passwordStr;

	usernameStr	= calloc(1, (username->Length/2)+1);
	passwordStr	= calloc(1, (password->Length/2)+1);

	wcstombs(usernameStr, username->Buffer, (username->Length/2));
	wcstombs(passwordStr, password->Buffer, (password->Length/2));

	retVal =
		pshk_exec_prog(PSHK_PRE_CHANGE, pshk_config, usernameStr, passwordStr);

	return retVal==PSHK_SUCCESS?TRUE:FALSE;
}


/* This is the initialization function */
BOOL NTAPI InitializeChangeNotify( void )
{
	/* Read the configuration from the registry */
	pshk_config = pshk_read_registry();

	if( ! pshk_config.valid )
		return FALSE;

	/* Open the logfile */
	if( pshk_config.logLevel > 0 && ! pshk_log_open( &pshk_config ) )
		return FALSE;

	pshk_log_write(&pshk_config, "Init "PSHK_BORDER);
	pshk_log_write(&pshk_config, pshk_struct2str(pshk_config));
	pshk_log_write(&pshk_config, "End Init"PSHK_BORDER"\r\n");

	/*Set the priority of passwd program*/
	if(pshk_config.priority == -1)
		pshk_config.processCreateFlags	|= IDLE_PRIORITY_CLASS;
	else if(pshk_config.priority == 1)
		pshk_config.processCreateFlags	|= HIGH_PRIORITY_CLASS;
	else pshk_config.processCreateFlags	|= NORMAL_PRIORITY_CLASS;

	/*Other creation flags*/
	pshk_config.processCreateFlags |= CREATE_NEW_PROCESS_GROUP|CREATE_NO_WINDOW;
	//pshk_config.processCreateFlags |= CREATE_NEW_PROCESS_GROUP;

	return TRUE;
}


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

#ifndef PASSWDHK_H
#define PASSWDHK_H

# include <stdio.h>
# include <stdlib.h>
# include <time.h>
# include <windows.h>
# include <ntsecapi.h>


#define PSHK_MAX_COMMANDLINE_LEN	256
#define PSHK_PRE_CHANGE				1
#define PSHK_POST_CHANGE			2
#define PSHK_SUCCESS				0
#define PSHK_FAILURE				1

/* Global static variable that holds config */
/* It is assumed that the LSA is single threaded */
/* All variables are readonly after initialization any */
typedef struct 
{
	int valid;
	int logLevel;
	DWORD maxLogSize;
	char *postChangeProg;
	char *postChangeProgArgs;
	char *preChangeProg;
	char *preChangeProgArgs;
	char *logFile;
	char *workingDir;
	char *environment;
	char *environmentStr;
	int priority;
	int processCreateFlags;
	int preChangeProgWait;
	int postChangeProgWait;
	BOOL urlencode;
	BOOL inheritParentHandles;
	HANDLE hChildSTDERR;
	HANDLE hChildSTDOUT;
	HANDLE hLogFile;
} pshkConfigStruct;

/* registry read functions */
# include "registry.h"

/* log access functions */
# include "logging.h"

/* misc. utility functions */
# include "util.h"

#endif
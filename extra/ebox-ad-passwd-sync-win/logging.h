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

#ifndef LOGGING_H
#define LOGGING_H

#define PSHK_LOG_ERROR		1
#define PSHK_LOG_DEBUG		2
#define PSHK_LOG_ALL		3

/* Open the log file */
/* NOTE: Once the file is opened, it is never closed */
BOOL pshk_log_open( pshkConfigStruct *c );

/* Write to the log file */
BOOL pshk_log_write( pshkConfigStruct *c, LPCSTR s );

#ifdef _DEBUG
/* Use during debuging only */
/* opens, writes, closes */
   void pshk_log_debug_log( LPCSTR s );
#  define PSHK_DEBUG_PRINT( x )	pshk_log_debug_log(x)
#else
#  define PSHK_DEBUG_PRINT( x )
#endif

#endif
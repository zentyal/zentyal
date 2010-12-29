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

#ifndef LOGGING_H
#define LOGGING_H

#define PSHK_LOG_ERROR		1
#define PSHK_LOG_DEBUG		2
#define PSHK_LOG_ALL		3

/* Open the log file */
/* NOTE: Once the file is opened, it is never closed */
HANDLE pshk_log_open();
void pshk_log_close(HANDLE h);
BOOL pshk_log_write_w(HANDLE h, LPCWSTR s);
BOOL pshk_log_write_a(HANDLE h, LPCSTR s);

#ifdef UNICODE
#define pshk_log_write pshk_log_write_w
#else
#define pshk_log_write pshk_log_write_a
#endif

#ifdef _DEBUG

/* Use during debuging only */
/* opens, writes, closes */
void pshk_log_debug_log_w(LPCTSTR s);
void pshk_log_debug_log_a(LPCSTR s);

#ifdef UNICODE
#define PSHK_DEBUG_PRINT(x) pshk_log_debug_log_w(x)
#else
#define PSHK_DEBUG_PRINT(x) pshk_log_debug_log_a(x)
#endif

#else

#define PSHK_DEBUG_PRINT(x)

#endif

#endif
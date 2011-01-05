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
**  OCT, 2010 - added alloc_copy functions
**
** Redistributed under the terms of the LGPL
** license.  See LICENSE.txt file included in
** this package for details.
**
********************************************************************/


#ifdef UNICODE
#define rawurlencode rawurlencode_w
#define alloc_copy alloc_copy_w
#else
#define rawurlencode rawurlencode_a
#define alloc_copy alloc_copy_a
#endif
LPWSTR alloc_copy_w(LPWSTR src, size_t length);
LPSTR alloc_copy_a(LPSTR src, size_t length);
LPTSTR pshk_struct2str();
LPWSTR rawurlencode_w(LPWSTR src);
LPSTR rawurlencode_a(LPSTR src);
int pshk_exec_prog(int option, TCHAR *username, TCHAR *password);

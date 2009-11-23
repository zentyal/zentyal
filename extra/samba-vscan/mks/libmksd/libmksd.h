/*
 * libmksd.h, ver. 1.05
 * copyright (c) MkS Sp. z o.o. 2002,2003
 * license: LGPL (see COPYING.LIB for details)
 */

#ifndef __LIBMKSD_H__
#define __LIBMKSD_H__

/* zwraca deskryptor otwartego polaczenia lub -1 (errno) */
int mksd_connect (void);

/* zwraca 0 lub -1; tablica na ans powinna miec jakies 4200 bajtow */
int mksd_query (const char *que, const char *prfx, char *ans);

void mksd_disconnect (void);

#endif

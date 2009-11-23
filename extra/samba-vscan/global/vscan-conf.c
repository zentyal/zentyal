/* 
 * $Id: vscan-conf.c,v 1.1 2003/07/15 11:37:35 mx2002 Exp $
 *
 * Code to read the SAMBA-VSCAN configuration
 *
 * Copyright (C) Stefan (metze) Metzmacher, 2003
 *               <metze@metzemix.de>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *  
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *  
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */


#include "vscan-global.h"

static int vscan_create_global_config(VSCAN_CONTEXT *context)
{
	context->config = (VSCAN_CONFIG *)talloc_zero(context->mem_ctx,sizeof(VSCAN_CONFIG));
	if (!context->config) {
		DEBUG(0,("talloc_zero() failed!\n"));
		errno = ENOMEM;
		return -1;
	}

	context->config->context = context;

	/* TODO:
	 * - set default values here
	 */

	return 0;
}

static int vscan_read_global_config(VSCAN_CONTEXT *context)
{
	/* TODO:
	 * - read the config file here
	 */

	return 0;
}

int vscan_global_config(VSCAN_CONTEXT *context)
{
	if (vscan_create_global_config(context)!=0) {
		DEBUG(0,("Failed to create global config struct!\n"));
		return -1;
	}

	if (vscan_read_global_config(context)!=0) {
		DEBUG(0,("Failed to read global config file [%s]!\n",
			context->config->file));
		return -1;
	}
	
	return 0;
}

int vscan_private_config(VSCAN_CONTEXT *context)
{
	/* TODO:
	 * - read private config here
	 */
	
	return 0;
}

BOOL vscan_on_open(VSCAN_CONTEXT *context)
{
	return context->config->scan_on_open;
}

BOOL vscan_on_close(VSCAN_CONTEXT *context)
{
	return context->config->scan_on_close;
}

BOOL vscan_on_sendfile(VSCAN_CONTEXT *context)
{
	return context->config->scan_on_sendfile;
}

BOOL vscan_on_rename(VSCAN_CONTEXT *context)
{
	return context->config->scan_on_rename;
}

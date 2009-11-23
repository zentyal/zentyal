/* 
 * $Id: vscan-backends.c,v 1.2 2003/07/15 11:37:35 mx2002 Exp $
 *
 * glue code between the samba-vscan VFS module
 * and the different scanner backends 
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

struct vscan_backend_entry {
	const char *name;
 	const VSCAN_FUNCTIONS *fns;
	struct vscan_backend_entry *prev, *next;
};

static struct vscan_backend_entry *backends = NULL;

static const VSCAN_FUNCTIONS *vscan_find_backend_fns(const char *name)
{
	struct vscan_backend_entry *entry = backends;
 
	while(entry) {
		if (strcmp(entry->name, name)==0) 
			return entry->fns;
		entry = entry->next;
	}

	return NULL;
}

NTSTATUS vscan_register_backend(int version, const char *name, const VSCAN_FUNCTIONS *fns)
{
	struct vscan_backend_entry *entry;

 	if ((version != VSCAN_CONTEXT_VERSION)) {
		DEBUG(0, ("Failed to register samba-vscan module.\n"
		          "The module was compiled against VSCAN_CONTEXT_VERSION %d,\n"
		          "current VSCAN_CONTEXT_VERSION is %d.\n"
		          "Please recompile against the current samba-vscan Version!\n",
			  version, VSCAN_CONTEXT_VERSION));
		return NT_STATUS_OBJECT_TYPE_MISMATCH;
  	}

	if (!name || !name[0] || !fns) {
		DEBUG(0,("smb_register_vfs() called with NULL pointer or empty name!\n"));
		return NT_STATUS_INVALID_PARAMETER;
	}

	if (vscan_find_backend_fns(name)) {
		DEBUG(0,("VFS module %s already loaded!\n", name));
		return NT_STATUS_OBJECT_NAME_COLLISION;
	}

	entry = smb_xmalloc(sizeof(struct vscan_backend_entry));
	entry->name = smb_xstrdup(name);
	entry->fns = fns;

	DLIST_ADD(backends, entry);
	DEBUG(5, ("Successfully added samba-vscan backend '%s'\n", name));
	return NT_STATUS_OK;
}

static void vscan_init_static_backends(void)
{
	static BOOL is_init;
	
	if (is_init) {
		return;
	} else {
		is_init = True;
	}

	/* register all static backend here */
	/* vscan_init_static is a macro defined in vscan-config.h */
	/* vscan_init_static; */
	vscan_init_oav();
}

static int vscan_select_backend(VSCAN_CONTEXT *context)
{
	const VSCAN_FUNCTIONS *fns;

	fns = vscan_find_backend_fns(context->config->backend);
	if (!fns) {
		DEBUG(0,("Failed to find functions for samba-vscan backend [%s]!\n",
			context->config->backend));
		return -1;	
	}

	context->backend = (VSCAN_BACKEND *)talloc_zero(context->mem_ctx, sizeof(VSCAN_BACKEND));
	if (!context->backend) {
		DEBUG(0,("talloc_zero() failed!\n"));
		errno = ENOMEM;
		return -1;
	}

	context->backend->context = context;

	context->backend->fns = fns;

	return 0;
}

/***********************************************************
 This function are used to call the backends functions from 
 the vscan core module
***********************************************************/

static int vscan_call_init1(VSCAN_CONTEXT *context)
{
	if (!context->backend->fns->init1) {
		return 0;
	}

	return context->backend->fns->init1(context);
}

static int vscan_call_config(VSCAN_CONTEXT *context)
{
	if (!context->backend->fns->config) {
		return 0;
	}

	return context->backend->fns->config(context);
}

static int vscan_call_init2(VSCAN_CONTEXT *context)
{
	if (!context->backend->fns->init2) {
		return 0;
	}

	return context->backend->fns->init2(context);
}

int vscan_call_open(VSCAN_CONTEXT *context)
{
	if (!context->backend->fns->open) {
		return 0;
	}

	return context->backend->fns->open(context);
}

int vscan_call_scan(VSCAN_CONTEXT *context, const char *fname, const char *newname, int flags, mode_t mode)
{
	if (!context->backend->fns->scan) {
		/* It makes no sense to have no scan function!
		   Deny access in this case! */ 
		errno = EACCES;
		return -1;
	}

	return context->backend->fns->scan(context, fname, newname, flags, mode);
}

int vscan_call_close(VSCAN_CONTEXT *context)
{
	if (!context->backend->fns->close) {
		return 0;
	}

	return context->backend->fns->close(context);
}

static int vscan_call_fini(VSCAN_CONTEXT *context)
{
	if (!context->backend->fns->fini) {
		return 0;
	}

	return context->backend->fns->fini(context);
}

VSCAN_CONTEXT *vscan_create_context(vfs_handle_struct *handle)
{
	VSCAN_CONTEXT *context = NULL;
	
	vscan_init_static_backends();

	context = (VSCAN_CONTEXT *)talloc_zero(handle->conn->mem_ctx, sizeof(VSCAN_CONTEXT));
	if (!context) {
		DEBUG(0,("talloc_zero() failed!\n"));
		return NULL;
	}

	context->mem_ctx = handle->conn->mem_ctx;
	context->handle = handle;

	if (vscan_global_config(context)!=0) {
		DEBUG(0,("Cannot read global configuration!\n"));
		return NULL;
	}

	if (vscan_select_backend(context)!=0) {
		DEBUG(0,("Failed to select samba-vscan backend [%s]!\n",
			context->config->backend));
		return NULL;
	}

	if (vscan_call_init1(context)!=0) {
		DEBUG(0,("vscan_init1() failed for samba-vscan backend [%s]!\n",
			context->config->backend));
		return NULL;
	}
	
	if (vscan_private_config(context)!=0) {
		DEBUG(0,("Failed to read private configuration for samba-vscan backend [%s]!\n",
			context->config->backend));
		return NULL;
	}

	if (vscan_call_init2(context)!=0) {
		DEBUG(0,("vscan_call_init2() failed for samba-vscan backend [%s]!\n",
			context->config->backend));
		return NULL;
	}
	
	return context;
}

void vscan_destroy_context(VSCAN_CONTEXT *context)
{
	vscan_call_fini(context);
}

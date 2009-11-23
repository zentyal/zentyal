/* 
 * $Id: vscan-vfs.c,v 1.2 2003/07/15 11:37:35 mx2002 Exp $
 *
 * SAMBA-VSCAN core VFS module
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

static int vscan_do_filescan(VSCAN_CONTEXT *context, const char *fname, const char *newname, int flags, mode_t mode)
{
	int ret = -1;

	if (vscan_call_open(context)!=0) {
		return -1;
	}

	if ((ret=vscan_call_scan(context, fname, newname, flags, mode))!=0) {
		/* IS SOMETHING TODO HERE ??? */
	}

	vscan_call_close(context);

	return ret;
}

static int vscan_connect(vfs_handle_struct *handle, connection_struct *conn, const char *service, const char *user)
{
	VSCAN_CONTEXT *context = NULL;

	context = vscan_create_context(handle);
	if (!context) {
		DEBUG(0,("Failed to create samba-vscan context!\n"));
		return -1;
	}

	SMB_VFS_HANDLE_SET_DATA(handle,context,NULL,VSCAN_CONTEXT,return -1);

	return SMB_VFS_NEXT_CONNECT(handle, conn, service, user);
}

static void vscan_disconnect(vfs_handle_struct *handle, connection_struct *conn)
{
	VSCAN_CONTEXT *context = NULL;
	
	SMB_VFS_HANDLE_GET_DATA(handle,context,VSCAN_CONTEXT,return);

	vscan_destroy_context(context);

	SMB_VFS_NEXT_DISCONNECT(handle, conn);
}

static int vscan_open(vfs_handle_struct *handle, connection_struct *conn, const char *fname, int flags, mode_t mode)
{
	VSCAN_CONTEXT *context = NULL;

	SMB_VFS_HANDLE_GET_DATA(handle,context,VSCAN_CONTEXT,return -1);

	if (vscan_on_open(context)) {
		if (vscan_do_filescan(context,fname,NULL,flags,mode)!=0) {
			return -1;
		}
	}

	return SMB_VFS_NEXT_OPEN(handle, conn, fname, flags, mode);
}

static int vscan_close(vfs_handle_struct *handle, files_struct *fsp, int fd)
{
	VSCAN_CONTEXT *context = NULL;
	int ret = SMB_VFS_NEXT_CLOSE(handle, fsp, fd);

	SMB_VFS_HANDLE_GET_DATA(handle,context,VSCAN_CONTEXT,return -1);

	if (vscan_on_close(context)) {
		if (vscan_do_filescan(context,fsp->fsp_name,NULL,0,0)!=0) {
			return -1;
		}
	}

	return ret;
}

static ssize_t vscan_sendfile(vfs_handle_struct *handle, int tofd, files_struct *fsp, int fromfd, const DATA_BLOB *header, SMB_OFF_T offset, size_t count)
{
	VSCAN_CONTEXT *context = NULL;

	SMB_VFS_HANDLE_GET_DATA(handle,context,VSCAN_CONTEXT,return -1);

	if (vscan_on_sendfile(context)) {
		if (vscan_do_filescan(context,fsp->fsp_name,NULL,0,0)!=0) {
			return -1;
		}
	}

	return SMB_VFS_NEXT_SENDFILE(handle, tofd, fsp, fromfd, header, offset, count);
}

static int vscan_rename(vfs_handle_struct *handle, connection_struct *conn, const char *oldname, const char *newname)
{
	VSCAN_CONTEXT *context = NULL;

	SMB_VFS_HANDLE_GET_DATA(handle,context,VSCAN_CONTEXT,return -1);

	if (vscan_on_rename(context)) {
		if (vscan_do_filescan(context,oldname,newname,0,0)!=0) {
			return -1;
		}
	}

	return SMB_VFS_NEXT_RENAME(handle, conn, oldname, newname);
}

static vfs_op_tuple vscan_op_tuples[] = {
	/* Disk operations */
	{SMB_VFS_OP(vscan_connect),	SMB_VFS_OP_CONNECT,	SMB_VFS_LAYER_TRANSPARENT},
	{SMB_VFS_OP(vscan_disconnect),	SMB_VFS_OP_DISCONNECT,	SMB_VFS_LAYER_TRANSPARENT},

	/* File operations */
	{SMB_VFS_OP(vscan_open),	SMB_VFS_OP_OPEN,	SMB_VFS_LAYER_TRANSPARENT},
	{SMB_VFS_OP(vscan_close),	SMB_VFS_OP_CLOSE,	SMB_VFS_LAYER_TRANSPARENT},
	{SMB_VFS_OP(vscan_sendfile),	SMB_VFS_OP_SENDFILE,	SMB_VFS_LAYER_TRANSPARENT},
	{SMB_VFS_OP(vscan_rename),	SMB_VFS_OP_RENAME,	SMB_VFS_LAYER_TRANSPARENT},

	/* Finish VFS operations definition */
	{NULL, 				SMB_VFS_OP_NOOP,	SMB_VFS_LAYER_NOOP}
};

NTSTATUS init_module(void)
{
	return smb_register_vfs(SMB_VFS_INTERFACE_VERSION, "vscan", vscan_op_tuples);
}

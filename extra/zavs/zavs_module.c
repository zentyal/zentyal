/*
 * Copyright (C) eBox Technologies, 2012
 *
 * Zentyal antivirus for samba - zavs
 *
 * AntiVirus VFS module for samba.  Log infected files via syslog
 * facility and block access using Clam AntiVirus Daemon.
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

#include <includes.h>
#include "zavs_core.h"
#include "zavs_log.h"

static int zavs_connect(vfs_handle_struct *handle, const char *service, const char *user)
{
    const char *address = get_remote_machine_name();
	zavs_initialize(handle, service, user, address);

    return SMB_VFS_NEXT_CONNECT(handle, service, user);
}

static void zavs_disconnect(vfs_handle_struct *handle)
{
    zavs_finalize();
    SMB_VFS_NEXT_DISCONNECT(handle);
}

static int zavs_open(vfs_handle_struct *handle, struct smb_filename *smb_fname, files_struct *fsp, int flags, mode_t mode)
{
    if (zavs_open_handler(handle, fsp)) {
        return SMB_VFS_NEXT_OPEN(handle, smb_fname, fsp, flags, mode);
    } else {
        errno = EACCES;
        return -1;
    }
}

static int zavs_close(vfs_handle_struct *handle, files_struct *fsp)
{
    // First close the file
    int retval = SMB_VFS_NEXT_CLOSE(handle, fsp);
    zavs_close_handler(handle, fsp);
    return retval;
}

static struct vfs_fn_pointers zavs_fn_pointers = {
    .connect_fn = zavs_connect,
    .disconnect_fn = zavs_disconnect,
    .open_fn = zavs_open,
    .close_fn = zavs_close,
};

NTSTATUS samba_init_module(void)
{
    return smb_register_vfs(SMB_VFS_INTERFACE_VERSION, "zavs", &zavs_fn_pointers);
}

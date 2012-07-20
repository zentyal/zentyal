#ifndef __VFS_ZAVS_H__
#define __VFS_ZAVS_H__

#include <includes.h>

//TODO Get this stuff dinamically
#define MODULE_VERSION "0.1"
#define SAMBA_VERSION "4.0.0beta2"

void zavs_initialize(vfs_handle_struct *handle, const char *service, const char *user, const char *address);
void zavs_finalize(void);
bool zavs_open_handler(vfs_handle_struct *handle, files_struct *fsp);
void zavs_close_handler(vfs_handle_struct *handle, files_struct *fsp);

bool skip_file(vfs_handle_struct *handle, files_struct *fsp, const char *filepath);
void build_filepath();

#endif

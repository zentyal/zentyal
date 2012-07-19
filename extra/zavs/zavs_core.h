#ifndef __VFS_ZAVS_H__
#define __VFS_ZAVS_H__

#include <includes.h>

//TODO Get this stuff dinamically
#define MODULE_VERSION "0.1"
#define SAMBA_VERSION "4.0.0beta2"

// Default location of the configuration file
#define CONF_FILE "/etc/samba/zavs.conf"

void zavs_initialize(vfs_handle_struct *handle, const char *service, const char *user, const char *address);
void zavs_finalize(void);

#endif

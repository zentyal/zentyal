#ifndef __ZAVS_QUARANTINE_H_
#define __ZAVS_QUARANTINE_H_

#include <lib/param/loadparm.h>

#define INFECTED_QUARANTINE 0
#define INFECTED_DELETE     1
#define INFECTED_NOTHING    2

static const struct enum_list infected_file_action_enum[] = {
    { INFECTED_QUARANTINE, "quarantine" },
    { INFECTED_DELETE,     "delete"     },
    { INFECTED_NOTHING,    "nothing"    },
    { -1, NULL}
};


///* functions by vscan-quarantine.c */
//
//#if (SMB_VFS_INTERFACE_VERSION >= 6)
///* quarantines an infected file by renaming it */
//int vscan_quarantine_virus(vfs_handle_struct *handle, connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix);
///* deletes an infected file */
//int vscan_delete_virus(vfs_handle_struct *handle, connection_struct *conn, char *virus_file);
//
///* decides, what do with an infected file based on user setting */
//int vscan_do_infected_file_action(vfs_handle_struct *handle, struct connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix, enum infected_file_action_enum infected_file_action);
//#else
///* quarantines an infected file by renaming it */
//int vscan_quarantine_virus(struct vfs_ops *ops, struct connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix);
///* deletes an infected file */
//int vscan_delete_virus(struct vfs_ops *ops, struct connection_struct *conn, char *virus_file);
//
///* decides, what do with an infected file based on user setting */
//int vscan_do_infected_file_action(struct vfs_ops *ops, struct connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix, enum infected_file_action_enum infected_file_action);
//#endif

#endif

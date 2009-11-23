#ifndef __VSCAN_QUARANTINE_H_
#define __VSCAN_QUARANTINE_H_


/* possible actions */

enum infected_file_action_enum {
	INFECTED_QUARANTINE,
	INFECTED_DELETE,
	INFECTED_DO_NOTHING
};



/* functions by vscan-quarantine.c */

#if (SMB_VFS_INTERFACE_VERSION >= 6)
/* quarantines an infected file by renaming it */
int vscan_quarantine_virus(vfs_handle_struct *handle, connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix);
/* deletes an infected file */
int vscan_delete_virus(vfs_handle_struct *handle, connection_struct *conn, char *virus_file);

/* decides, what do with an infected file based on user setting */
int vscan_do_infected_file_action(vfs_handle_struct *handle, struct connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix, enum infected_file_action_enum infected_file_action);
#else
/* quarantines an infected file by renaming it */
int vscan_quarantine_virus(struct vfs_ops *ops, struct connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix);
/* deletes an infected file */
int vscan_delete_virus(struct vfs_ops *ops, struct connection_struct *conn, char *virus_file);

/* decides, what do with an infected file based on user setting */
int vscan_do_infected_file_action(struct vfs_ops *ops, struct connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix, enum infected_file_action_enum infected_file_action);
#endif

#endif /* __VSCAN_QUARANTINE_H_ */

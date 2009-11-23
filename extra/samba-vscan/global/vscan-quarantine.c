/* 
 * $Id: vscan-quarantine.c,v 1.6 2003/06/18 06:01:03 mx2002 Exp $
 *
 * Provides functions for quarantining or removing an infected file
 *
 * Copyright (C) Kurt Huwig, 2002
 *		 OpenAntiVirus.org <kurt@openantivirus.org>
 *		 Rainer Link, 2002
 *		 OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/

#include "vscan-global.h"

/*
  deletes the infected file
*/
 
#if (SMB_VFS_INTERFACE_VERSION >= 6)
int vscan_delete_virus(vfs_handle_struct *handle, connection_struct *conn, char *virus_file) {
	int rc = SMB_VFS_NEXT_UNLINK(handle, conn, virus_file);
#else 
int vscan_delete_virus(struct vfs_ops *ops, struct connection_struct *conn, char *virus_file) {
	int rc = ops->unlink(conn, virus_file);
#endif

	if (rc) {
		vscan_syslog_alert("ERROR: removing file '%s' failed, reason: %s", virus_file, strerror(errno));
		return rc;
	}
	vscan_syslog("INFO: file '%s' removed successfully", virus_file);
	return 0;
}

/*
  moves the infected file to quarantine
*/
#if (SMB_VFS_INTERFACE_VERSION >= 6)
int vscan_quarantine_virus(vfs_handle_struct *handle, connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix) {
#else
int vscan_quarantine_virus(struct vfs_ops *ops, struct connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix) {
#endif
	int rc;
	/* FIXME: tempnam should be avoided */
	char *q_file = tempnam(q_dir, q_prefix);

	if (q_file == NULL) {
		vscan_syslog_alert("ERROR: cannot create unique quarantine filename. Probably a permission problem with directory %s", q_dir);
		return -1;
	}
#if (SMB_VFS_INTERFACE_VERSION >= 6)
	rc = SMB_VFS_NEXT_RENAME(handle, conn, virus_file, q_file);
#else
	rc = ops->rename(conn, virus_file, q_file);
#endif
	if (rc) {
		vscan_syslog_alert("ERROR: quarantining file '%s' to '%s' failed, reason: %s", virus_file, q_file, strerror(errno));

/* FIXME: we should not remove any file per default. An infected word document 
   may contain important data. Add "delete file on quarantine failure" for
   the next version.
		return vscan_delete_virus(ops, conn, virus_file);
*/
		return -1;
	}
	vscan_syslog("INFO: quarantining file '%s' to '%s' was successful", virus_file, q_file);
	return 0;
}
 
#if (SMB_VFS_INTERFACE_VERSION >= 6)
int vscan_do_infected_file_action(vfs_handle_struct *handle_ops, connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix, enum infected_file_action_enum infected_file_action) {
#else
int vscan_do_infected_file_action(struct vfs_ops *handle_ops, struct connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix, enum infected_file_action_enum infected_file_action) {
#endif
	int rc = -1;

	switch (infected_file_action) {
	case INFECTED_QUARANTINE:
		rc = vscan_quarantine_virus(handle_ops, conn, virus_file, q_dir, q_prefix);
		break;
	case INFECTED_DELETE:
		rc = vscan_delete_virus(handle_ops, conn, virus_file);
		break;
	case INFECTED_DO_NOTHING:
		rc = 0;
		break;
	default:
		vscan_syslog_alert("unknown infected file action %d!", infected_file_action);
		break; /* FIXME: do we really need a break here?!? */
	}

	return rc;
}

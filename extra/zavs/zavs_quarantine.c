/* 
 * $Id: vscan-quarantine.c,v 1.4.2.4 2007/05/19 17:59:42 reniar Exp $
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

/**
 * deletes the infected file
 * @param handle		pointer to vfs_handle_struct structure
 * @param connection_struct	pointer to connect_struct structure
 * @param virus_file		filepath of infected file	
 * @return
 *	 0			success, file deleted
 *     !=0			failure, file not deleted
*/
 
#if (SMB_VFS_INTERFACE_VERSION >= 6)
int vscan_delete_virus(vfs_handle_struct *handle, connection_struct *conn, char *virus_file) {
	#if (SMB_VFS_INTERFACE_VERSION >= 21)
         int rc = SMB_VFS_NEXT_UNLINK(handle, virus_file);
        #else 
	 int rc = SMB_VFS_NEXT_UNLINK(handle, conn, virus_file);
	#endif
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

/**
 * moves the infected file to quarantine
 * @param handle		pointer to vfs_handle_struct structure
 * @param conn			pointer to connection_struct strucute
 * @param virus_file		filepath of infected file
 * @param q_dir			quarantine directory
 * @param q_prefix		prefix of quarantine file
 * @return
 *	 0 			success, file quarantined
 *     !=0			failure, file not quarantined
*/
#if (SMB_VFS_INTERFACE_VERSION >= 6)
int vscan_quarantine_virus(vfs_handle_struct *handle, connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix) {
#else
int vscan_quarantine_virus(struct vfs_ops *ops, struct connection_struct *conn, char *virus_file, char *q_dir, char *q_prefix) {
#endif
	int rc, fd;
	pstring q_file;

	/* build file path */
	pstrcpy(q_file, q_dir);
	pstrcat(q_file, "/");
	pstrcat(q_file, q_prefix);
	pstrcat(q_file, "XXXXXX");

	/* create temp file, q_file filled with temp file path */
	/* NOTE: q_dir shoud have the sticky bit set! mkstemp creates
	   a zero-byte file, but as long as rename(2) overwrites the
	   newpath this isn't a problem */
	fd = smb_mkstemp(q_file);
	DEBUG(3, ("temp file is: %s\n", q_file));

	if ( fd == -1 ) {
		/* FIXME: we could call strerror, too */
		vscan_syslog_alert("ERROR: cannot create unique quarantine filename. Probably a permission problem with directory %s", q_dir);
		return -1;
	}
	/* close the opened, 0-byte file */
	rc = close(fd);
	if ( rc == -1 ) {
		vscan_syslog_alert("ERROR while closing quarantine file: %s, reason: %s", q_file, strerror(errno));
		return -1;
	}
	
	/* now do the actual quarantine, i.e. renaming */
#if (SMB_VFS_INTERFACE_VERSION >= 21)
	rc = SMB_VFS_NEXT_RENAME(handle, virus_file, q_file);
#elif (SMB_VFS_INTERFACE_VERSION >= 6)
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

/**
 do action on infected file
*/ 
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

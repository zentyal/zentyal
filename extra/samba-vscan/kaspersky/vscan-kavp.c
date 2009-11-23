/* 
 * $Id: vscan-kavp.c,v 1.44 2003/06/25 10:19:15 mx2002 Exp $
 *
 * virusscanning VFS module for samba.  Log infected files via syslog
 * facility and block access using Kaspersky AntiVirus.
 *
 * Copyright (C) Rainer Link, 2001-2003
 *               OpenAntiVirus.org <rainer@openantivirus.org>
 * Copyright (C) Stefan (metze) Metzmacher, 2003
 *               <metze@metzemix.de>
 *
 * based on vscan-kavp by
 * Copyright (C) Ries van Twisk (vscan@rvt.dds.nl), 2002
 *
 * based on the audit VFS module by
 * Copyright (C) Tim Potter, 1999-2000
 * Copyright (C) Alexander Bokovoy, 2002
 *
 * based on the sample KAVP client sources by
 * Copyright (C) Kaspersky Labs, 2001
 *
 * 
 * includes some fixes by Kevin Wang <kjw@rightsock.com>, 2003
 *
 * Credits to
 * - Dave Collier-Brown for his VFS tutorial (http://www.geocities.com/orville_torpid/papers/vfs_tutorial.html)
 * - REYNAUD Jean-Samuel for helping me to solve some general Samba VFS issues at the first place
 * - Simon Harrison for his solution without Samba VFS (http://www.smh.uklinux.net/linux/sophos.html)
 * - the whole Samba Team :)
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
#include "vscan-kavp.h"

#include "vscan-vfs.h"

#define VSCAN_MODULE_STR "vscan-kavp"

fstring config_file;            /* location of config file, either
                                   PARAMCONF or as set via vfs options
                                */

ssize_t max_size;          	/* do not scan files greater than max_size
                                   if max_size = 0, scan any file
                                */

BOOL verbose_file_logging;  	/* log ever file access */

BOOL scan_on_open;         	/* scan a file before it is opened
                                   Defaults to True
                                */

BOOL scan_on_close;        	/* scan a new file put on share or
                                   if file was modified
                                   Defaults to False
                                */

BOOL deny_access_on_error;      /* if connection to daemon fails,  should access to any
                                   file be denied? Defaults to True 
				*/


BOOL deny_access_on_minor_error; /* if daemon returns non-critical error,
                                    should access to the file be denied? */

BOOL send_warning_message;	/* send a warning message using the windows
				   messenger service? */

fstring avpctl;			/* socket name for kavdaemon */

fstring quarantine_dir;	/* directory for infected files */
fstring quarantine_prefix;	/* prefix    for infected files */

enum infected_file_action_enum infected_file_action; /* what to do with infected files;
                                                        defaults to quarantine */

int max_lrufiles;               /* specified the maximum entries in lrufiles list */
time_t lrufiles_invalidate_time; /* specified the time in seconds after the lifetime
                                    of an entry is expired and entry will be invalidated */

/* module version */
static const char module_id[]=VSCAN_MODULE_STR" "SAMBA_VSCAN_VERSION_STR;


static BOOL do_parameter(const char *param, const char *value)
{
        if ( StrCaseCmp("max file size", param) == 0 ) {
		/* FIXME: sanity check missing! what, if value is out of range?
		   atoi returns int - what about LFS? atoi should be avoided!
		*/
                max_size = atoi(value);
                DEBUG(3, ("max file size is: %d\n", max_size));
        } else if ( StrCaseCmp("verbose file logging", param) == 0 ) {
                set_boolean(&verbose_file_logging, value);
                DEBUG(3, ("verbose file logging is: %d\n", verbose_file_logging));
        } else if ( StrCaseCmp("scan on open", param) == 0 ) {
                set_boolean(&scan_on_open, value);
                DEBUG(3, ("scan on open: %d\n", scan_on_open));
        } else if ( StrCaseCmp("scan on close", param) == 0 ) {
                set_boolean(&scan_on_close, value);
                DEBUG(3, ("scan on close is: %d\n", scan_on_close));
        } else if ( StrCaseCmp("deny access on error", param) == 0 ) {
                set_boolean(&deny_access_on_error, value);
                DEBUG(3, ("deny access on error is: %d\n", deny_access_on_error));
        } else if ( StrCaseCmp("deny access on minor error", param) == 0 ) {
                set_boolean(&deny_access_on_minor_error, value);
                DEBUG(3, ("deny access on minor error is: %d\n", deny_access_on_minor_error));
        } else if ( StrCaseCmp("send warning message", param) == 0 ) {
                set_boolean(&send_warning_message, value);
                DEBUG(3, ("send warning message is: %d\n", send_warning_message));
        } else if ( StrCaseCmp("infected file action", param) == 0 ) {
		if (StrCaseCmp("quarantine", value) == 0) {
			infected_file_action = INFECTED_QUARANTINE;
		} else if (StrCaseCmp("delete", value) == 0) {
			infected_file_action = INFECTED_DELETE;
		} else if (StrCaseCmp("nothing", value) == 0) {
			infected_file_action = INFECTED_DO_NOTHING;
		} else {
			DEBUG(2, ("samba-vscan: badly formed infected file action in configuration file, parameter %s\n", value));
		}
                DEBUG(3, ("infected file action is: %d\n", infected_file_action));
        } else if ( StrCaseCmp("quarantine directory", param) == 0 ) {
                fstrcpy(quarantine_dir, value);
                DEBUG(3, ("quarantine directory is: %s\n", quarantine_dir));
        } else if ( StrCaseCmp("quarantine prefix", param) == 0 ) {
                fstrcpy(quarantine_prefix, value);
                DEBUG(3, ("quarantine prefix is: %s\n", quarantine_prefix));
        } else if ( StrCaseCmp("max lru files entries", param) == 0 ) {
                max_lrufiles = atoi(value);
                DEBUG(3, ("max lru files entries is: %d\n", max_lrufiles));
        } else if ( StrCaseCmp("lru file entry lifetime", param) == 0 ) {
                lrufiles_invalidate_time = atol(value);
                DEBUG(3, ("lru file entry lifetime is: %li\n", (long)lrufiles_invalidate_time));
	} else if ( StrCaseCmp("avp socket file", param) == 0 ) {
		fstrcpy(avpctl, value);
		DEBUG(3, ("avp socket file is: %s\n", avpctl));
        } else
                DEBUG(3, ("unknown parameter: %s\n", param));

        return True;
}

static BOOL do_section(const char *section)
{
        /* simply return true, there's only one section :-) */
        return True;
}




/* Implementation of vfs_ops.  */

#if (SMB_VFS_INTERFACE_VERSION >= 6)
static int vscan_connect(vfs_handle_struct *handle, connection_struct *conn, const char *svc, const char *user)
#else
static int vscan_connect(struct connection_struct *conn, PROTOTYPE_CONST char *svc, PROTOTYPE_CONST char *user)
#endif
{
	#if (SAMBA_VERSION_MAJOR==2 && SAMBA_VERSION_RELEASE>=4) || SAMBA_VERSION_MAJOR==3
	 #if !(SMB_VFS_INTERFACE_VERSION >= 6)
          pstring opts_str;
          PROTOTYPE_CONST char *p;
	 #endif
	#endif
        int retval;

#if (SMB_VFS_INTERFACE_VERSION >= 6)
        vscan_syslog("samba-vscan (%s) connected (Samba 3.0), (c) by Rainer Link, OpenAntiVirus.org", module_id);
#endif

        /* set default value for configuration files */
        fstrcpy(config_file, PARAMCONF);

        /* set default value for max file size */
        max_size = VSCAN_MAX_SIZE;

        /* set default value for file logging */
        verbose_file_logging = VSCAN_VERBOSE_FILE_LOGGING;

        /* set default value for scan on open() */
        scan_on_open = VSCAN_SCAN_ON_OPEN;

        /* set default value for scan on close() */
        scan_on_close = VSCAN_SCAN_ON_CLOSE;

        /* set default value for deny access on error */
        deny_access_on_error = VSCAN_DENY_ACCESS_ON_ERROR;

	/* set default value for deny access on minor error */
	deny_access_on_minor_error = VSCAN_DENY_ACCESS_ON_MINOR_ERROR;
 
	/* set default value for send warning message */
	send_warning_message = VSCAN_SEND_WARNING_MESSAGE;

        /* set default value for infected file action */
        infected_file_action = VSCAN_INFECTED_FILE_ACTION;

        /* set default value for quarantine directory */
        fstrcpy(quarantine_dir, VSCAN_QUARANTINE_DIRECTORY);

        /* set default value for quarantine prefix */
        fstrcpy(quarantine_prefix, VSCAN_QUARANTINE_PREFIX);

	/* set default value for kavdaemon socket file (AVPCTL) */
	fstrcpy(avpctl, AVPCTL);

        /* set default value for maximum lrufile entries */
        max_lrufiles = VSCAN_MAX_LRUFILES;

        /* time after an entry is considered as expired */
        lrufiles_invalidate_time = VSCAN_LRUFILES_INVALIDATE_TIME;


	vscan_syslog("INFO: connect to service %s by user %s", 
	       svc, user);

	#if (SAMBA_VERSION_MAJOR==2 && SAMBA_VERSION_RELEASE>=4) || SAMBA_VERSION_MAJOR==3
	 #if (SMB_VFS_INTERFACE_VERSION >= 6)
	  fstrcpy(config_file, lp_parm_const_string(SNUM(conn),VSCAN_MODULE_STR,"config-file",PARAMCONF));
	 #else
          pstrcpy(opts_str, (const char*) lp_vfs_options(SNUM(conn)));
          if( !*opts_str ) {
                DEBUG(3, ("samba-vscan: no configuration file set - using default value (%s).\n", lp_vfs_options(SNUM(conn))));
          } else {
                p = opts_str;
                if ( next_token(&p, config_file, "=", sizeof(config_file)) ) {
                        trim_string(config_file, " ", " ");
                        if ( !strequal("config-file", config_file) ) {
                                DEBUG(3, ("samba-vscan - connect: options %s is not config-file\n", config_file));
                                /* setting default value */
                                fstrcpy(config_file, PARAMCONF);

                        } else {
                                if ( !next_token(&p, config_file," \n",sizeof(config_file)) ) {
                                        DEBUG(3, ("samba-vscan - connect: no option after config-file=\n"));
                                        /* setting default value */
                                        fstrcpy(config_file, PARAMCONF);
                                } else {
                                        trim_string(config_file, " ", " ");
                                        DEBUG(3, ("samba-vscan - connect: config file name is %s\n", config_file));
                                }
                        }
                }
          }
	  #endif /*  #if (SMB_VFS_INTERFACE_VERSION >= 6)*/
          retval = pm_process(config_file, do_section, do_parameter);
          DEBUG(10, ("pm_process returned %d\n", retval));
	  if (!retval) vscan_syslog("ERROR: could not parse configuration file '%s'. File not found or not read-able. Using compiled-in defaults", config_file);
	#endif


/*	vscan_kavp_init(); 
 * 	persistent connection causes trouble, when kavdaemon is sig-HUP'ed, as then
 *	we get an connection error for every file being accessed 
 * 	do _init and _close on the open() / close() call now
*/

        /* initialise lrufiles list */
        DEBUG(5, ("init lrufiles list\n"));
        lrufiles_init(max_lrufiles, lrufiles_invalidate_time);



	 #if (SMB_VFS_INTERFACE_VERSION >= 6)
	 return SMB_VFS_NEXT_CONNECT(handle, conn, svc, user);
	 #else
	 return default_vfs_ops.connect(conn, svc, user);
	 #endif

}

#if (SMB_VFS_INTERFACE_VERSION >= 6)
static void vscan_disconnect(vfs_handle_struct *handle, connection_struct *conn)
#else/* Samba 3.0 alphaX */
static void vscan_disconnect(struct connection_struct *conn)
#endif
{
	/* vscan_kavp_end(); */

	vscan_syslog("INFO: disconnected");

        lrufiles_destroy_all();

#if (SMB_VFS_INTERFACE_VERSION >= 6)
	SMB_VFS_NEXT_DISCONNECT(handle, conn);
#else
	default_vfs_ops.disconnect(conn);
#endif
}


#if (SMB_VFS_INTERFACE_VERSION >= 6)
static int vscan_open(vfs_handle_struct *handle, connection_struct *conn, const char *fname, int flags, mode_t mode)
#else
static int vscan_open(struct connection_struct *conn, PROTOTYPE_CONST char *fname, int flags, mode_t mode)
#endif
{
	int retval, must_be_checked;
	SMB_STRUCT_STAT stat_buf;
	pstring filepath;
	char client_ip[CLIENT_IP_SIZE];

	int rc;


        /* scan files while opening? */
        if ( !scan_on_open ) {
                DEBUG(3, ("samba-vscan - open: File '%s' not scanned as scan_on_open is not set\n", fname));
#if (SMB_VFS_INTERFACE_VERSION >= 6)
		return SMB_VFS_NEXT_OPEN(handle, conn, fname, flags, mode);
#else
                return default_vfs_ops.open(conn, fname, flags, mode);
#endif				
        }

	vscan_kavp_init();
	if ( kavp_socket < 0 && deny_access_on_error ) {

                        /* an error occured - can not communicate to daemon - deny access */
                        vscan_syslog("ERROR: can not communicate to daemon - access denied");
                        errno = EACCES;
			vscan_kavp_end();
                        return -1;
	} else {
#if (SMB_VFS_INTERFACE_VERSION >= 6)
        	if ( (SMB_VFS_NEXT_STAT(handle, conn, fname, &stat_buf)) != 0 ) {    /* an error occured */ 
			vscan_kavp_end();
			return SMB_VFS_NEXT_OPEN(handle, conn, fname, flags, mode);
			}
#else
	        if ( (default_vfs_ops.stat(conn, fname, &stat_buf)) != 0 ) {   /* an error occured */ 
			vscan_kavp_end();
			return default_vfs_ops.open(conn, fname, flags, mode);
			}
#endif
		else if ( S_ISDIR(stat_buf.st_mode) ) { 	/* is it a directory? */
			vscan_kavp_end();
#if (SMB_VFS_INTERFACE_VERSION >= 6)
			return SMB_VFS_NEXT_OPEN(handle, conn, fname, flags, mode);
#else
			return default_vfs_ops.open(conn, fname, flags, mode);
#endif
			}
		else if ( ( stat_buf.st_size > max_size ) && ( max_size > 0 ) ) { /* file is too large */
			vscan_syslog("INFO: File %s is larger than specified maximum file size! Not scanned!", fname);
			}
		else if ( stat_buf.st_size == 0 ) { /* do not scan empty files */
			vscan_kavp_end();
#if (SMB_VFS_INTERFACE_VERSION >= 6)
			return SMB_VFS_NEXT_OPEN(handle, conn, fname, flags, mode);
#else
			return default_vfs_ops.open(conn, fname, flags, mode);
#endif
			}
		else {
			/* Assemble complete file path */       
			pstrcpy(filepath, conn->connectpath);
			pstrcat(filepath, "/");  /* is "/" correct? */
			pstrcat(filepath, fname);       

			/* get client IP */
			safe_strcpy(client_ip, conn->client_address, CLIENT_IP_SIZE -1);

                        /* must file actually be scanned? */
                        must_be_checked = lrufiles_must_be_checked(filepath, stat_buf.st_mtime);
                        if ( must_be_checked == -1 ) {
                                /* file has already been checked and marked as infected */
                                /* deny access */
                                if ( verbose_file_logging )
                                        vscan_syslog("File '%s' has already been scanned and marked as infected. Not scanned any more. Access denied", filepath);
			
				/* close socket */
				vscan_kavp_end();
				
				/* deny access */
                                errno = EACCES;
                                return -1;
                        } else if ( must_be_checked == 0 )  {
                                /* file has already been checked, not marked as infected and not modified */
                                if ( verbose_file_logging )
                                        vscan_syslog("File '%s' has already been scanned, not marked as infected and not modified. Not scanned anymore. Access granted", filepath);

				/* close socket */
				vscan_kavp_end();
				
				/* grant access */
#if (SMB_VFS_INTERFACE_VERSION >= 6)
				return SMB_VFS_NEXT_OPEN(handle, conn, fname, flags, mode);
#else
				return default_vfs_ops.open(conn, fname, flags, mode);
#endif
                        }
                        /* ok, we must check the file */

			/* scan file */
			retval = vscan_kavp_scanfile(filepath, client_ip);
			if ( retval == -2 && deny_access_on_minor_error ) {
				/* a minor error occured - deny access */
				vscan_syslog("ERROR: daemon failed with a minor error - access to file %s denied", fname);
				vscan_kavp_end();
				
                                /* to be safe, remove file from lrufiles */
                                lrufiles_delete(filepath);

                                /* deny access */
				errno = EACCES;
				return -1;
                        } else if ( retval == -1 && deny_access_on_error ) {
                                /* an error occured - can not communicate to daemon - deny access */
                                vscan_syslog("ERROR: can not communicate to daemon - access to file %s denied", fname);
				vscan_kavp_end();

				/* to be safe, remove file from lrufiles */
                                lrufiles_delete(filepath);

                                /* deny access */

                                errno = EACCES;
                                return -1;
			} else if ( retval == 1 ) {
				/* virus was found */
				/* close socket */
				vscan_kavp_end();
				/* do action ... */
				
#if (SMB_VFS_INTERFACE_VERSION >= 6)
				rc = vscan_do_infected_file_action(handle, conn, filepath, quarantine_dir, quarantine_prefix, infected_file_action);
#else
				rc = vscan_do_infected_file_action(&default_vfs_ops, conn, filepath, quarantine_dir, quarantine_prefix, infected_file_action);
#endif

                                /* add/update file. mark file as infected! */
                                lrufiles_add(filepath, stat_buf.st_mtime, True);

				/* virus found, deny acces */
				errno = EACCES; 
				return -1;
                        } else if ( retval == 0 ) {
                                /* file is clean, add to lrufiles */
                                lrufiles_add(filepath, stat_buf.st_mtime, False);
                        }
		}

		/* close socket */
		vscan_kavp_end();

	}
#if (SMB_VFS_INTERFACE_VERSION >= 6)
	return SMB_VFS_NEXT_OPEN(handle, conn, fname, flags, mode);
#else
	return default_vfs_ops.open(conn, fname, flags, mode);
#endif
}

#if (SMB_VFS_INTERFACE_VERSION >= 6)
static int vscan_close(vfs_handle_struct *handle, files_struct *fsp, int fd)
#else
static int vscan_close(struct files_struct *fsp, int fd)
#endif
{
	pstring filepath;
        int retval, rv, rc;
	char client_ip[CLIENT_IP_SIZE];

        /* First close the file */
#if (SMB_VFS_INTERFACE_VERSION >= 6)
        retval = SMB_VFS_NEXT_CLOSE(handle, fsp, fd);
#else
        retval = default_vfs_ops.close(fsp, fd);
#endif

        if ( !scan_on_close ) {
                DEBUG(3, ("samba-vscan - close: File '%s' not scanned as scan_on_close is not set\n", fsp->fsp_name));
                return retval;
        }


	/* get the file name */
        pstrcpy(filepath, fsp->conn->connectpath);
        pstrcat(filepath, "/"); 
        pstrcat(filepath, fsp->fsp_name);        
	
        /* Don't scan directorys */
        if ( fsp->is_directory )
            return retval;


	if ( !fsp->modified ) {
                if ( verbose_file_logging ) 
                        vscan_syslog("INFO: file %s was not modified - not scanned", filepath);

		return retval;
	}

	/* scan only file, do nothing */	

	vscan_kavp_init();
	if ( kavp_socket >= 0 ) {
		safe_strcpy(client_ip, fsp->conn->client_address, CLIENT_IP_SIZE -1);
		rv = vscan_kavp_scanfile(filepath, client_ip);
		vscan_kavp_end();
		if ( rv == 1 ) {
			/* virus was found */
#if (SMB_VFS_INTERFACE_VERSION >= 6)
			rc = vscan_do_infected_file_action(handle, fsp->conn, filepath, quarantine_dir, quarantine_prefix, infected_file_action);
#else
			rc = vscan_do_infected_file_action(&default_vfs_ops, fsp->conn, filepath, quarantine_dir, quarantine_prefix, infected_file_action);
#endif
		}

	}
	return retval;
}


#if (SMB_VFS_INTERFACE_VERSION >= 6)
/* Samba 3.0 */
NTSTATUS init_module(void)
{
	NTSTATUS ret;
	
	ret = smb_register_vfs(SMB_VFS_INTERFACE_VERSION, VSCAN_MODULE_STR, vscan_ops);
	DEBUG(5,("samba-vscan (%s) registered (Samba 3.0), (c) by Rainer Link, OpenAntiVirus.org\n", module_id));
	openlog("smbd_"VSCAN_MODULE_STR, LOG_PID, SYSLOG_FACILITY);
		
	return ret;	
}
#else
/* VFS initialisation function.  Return initialised vfs_ops structure
   back to SAMBA. */
#if SAMBA_VERSION_MAJOR==3
 /* Samba 3.0 alphaX */
 vfs_op_tuple *vfs_init(int *vfs_version, struct vfs_ops *def_vfs_ops,
			struct smb_vfs_handle_struct *vfs_handle)
#else
 /* Samba 2.2.x */
 #if SAMBA_VERSION_RELEASE>=4   
  /* Samba 2.2.4 */
  struct vfs_ops *vfs_init(int *vfs_version, struct vfs_ops *def_vfs_ops)
 #elif SAMBA_VERSION_RELEASE==2
  /* Samba 2.2.2 / Samba 2.2.3 !!! */
  struct vfs_ops *vfs_init(int* Version, struct vfs_ops *ops)
 #elif SAMBA_VERSION_RELEASE==1
  /* Samba 2.2.1 */
  struct vfs_ops *vfs_module_init(int *vfs_version)
 #else
  /* Samba 2.2.0 */
  struct vfs_ops *vfs_init(int *vfs_version)
 #endif
#endif
{
	#if SAMBA_VERSION_MAJOR!=3
 	 #if SAMBA_VERSION_RELEASE>=4
	  /* Samba 2.2.4 */
	  struct vfs_ops tmp_ops;
	 #endif
	#endif

        openlog("smbd_"VSCAN_MODULE_STR, LOG_PID, SYSLOG_FACILITY);

        #if SAMBA_VERSION_MAJOR==3
         /* Samba 3.0 alphaX */
         *vfs_version = SMB_VFS_INTERFACE_VERSION;
         vscan_syslog("samba-vscan (%s) loaded (Samba 3.x), (c) by Rainer Link, OpenAntiVirus.org", module_id);
        #else
         /* Samba 2.2.x */
         #if SAMBA_VERSION_RELEASE>=4
          /* Samba 2.2.4 */
          *vfs_version = SMB_VFS_INTERFACE_VERSION;
          vscan_syslog("samba-vscan (%s) loaded (Samba >=2.2.4), (c) by Rainer Link, OpenAntiVirus.org", module_id);
         #elif SAMBA_VERSION_RELEASE==2
          /* Samba 2.2.2 / Samba 2.2.3 !!! */
          *Version = SMB_VFS_INTERFACE_VERSION;
          vscan_syslog("samba-vscan (%s) loaded (Samba 2.2.2/2.2.3), (c) by Rainer Link, OpenAntiVirus.org", module_id);
         #else
          /* Samba 2.2.1 / Samba 2.2.0 */
          *vfs_version = SMB_VFS_INTERFACE_VERSION;
          vscan_syslog("samba-vscan (%s) loaded (Samba 2.2.0/2.2.1), (c) by Rainer Link, OpenAntiVirus.org",
               module_id);
         #endif
        #endif


	#if SAMBA_VERSION_MAJOR==3
         /* Samba 3.0 alphaX */
	 DEBUG(3, ("Initialising default vfs hooks\n"));
         memcpy(&default_vfs_ops, def_vfs_ops, sizeof(struct vfs_ops));

         /* Remember vfs_handle for further allocation and referencing of 
	    private information in vfs_handle->data
         */
	 vscan_handle = vfs_handle;
	 return vscan_ops;
        #else
         /* Samba 2.2.x */
	 #if SAMBA_VERSION_RELEASE>=4
	  /* Samba 2.2.4 */

	  *vfs_version = SMB_VFS_INTERFACE_VERSION;
	  memcpy(&tmp_ops, def_vfs_ops, sizeof(struct vfs_ops));
	  tmp_ops.connect = vscan_connect;
	  tmp_ops.disconnect = vscan_disconnect;
	  tmp_ops.open = vscan_open;
	  tmp_ops.close = vscan_close;
	  memcpy(&vscan_ops, &tmp_ops, sizeof(struct vfs_ops));
	  return(&vscan_ops);

	 #else
          /* Samba 2.2.3-2.2.0 */
          return(&vscan_ops);
	 #endif
	#endif
}


#if SAMBA_VERSION_MAJOR==3
/* VFS finalization function */
void vfs_done(connection_struct *conn)
{
        DEBUG(3, ("Finalizing default vfs hooks\n"));
}
#endif

#endif /* #if (SMB_VFS_INTERFACE_VERSION >= 6) */

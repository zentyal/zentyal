/*
 * $Id: vscan-clamav.c,v 1.1.2.24 2007/05/21 08:43:32 reniar Exp $
 * 
 * virusscanning VFS module for samba.  Log infected files via syslog
 * facility and block access using Clam AntiVirus Daemon.
 *
 * Copyright (C) Rainer Link, 2001-2004
 *               OpenAntiVirus.org <rainer@openantivirus.org>
 *               Dariusz Markowicz <dariusz@markowicz.net>, 2003
 * Copyright (C) Stefan (metze) Metzmacher, 2003
 *               <metze@metzemix.de>
 *
 * based on the audit VFS module by
 * Copyright (C) Tim Potter, 1999-2000
 * Copyright (C) Alexander Bokovoy, 2002
 *
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
#include "vscan-clamav.h"

#include "vscan-vfs.h"

#ifdef LIBCLAMAV
#include <clamav.h>
#endif

#define VSCAN_MODULE_STR "vscan-clamav"

vscan_config_struct vscan_config; /* contains the vscan module configuration */

bool verbose_file_logging;
bool send_warning_message;

#ifdef LIBCLAMAV
struct cl_node *clamav_root = NULL;
struct cl_limits clamav_limits;
bool clamav_loaded = False;
#else
bool scanarchives;
fstring clamd_socket_name;      /* name of clamd socket */
#endif  

/* module version */
static const char module_id[]=VSCAN_MODULE_STR" "SAMBA_VSCAN_VERSION_STR;



static bool do_parameter(const char *param, const char *value, void *userdata)
{

        if ( do_common_parameter(&vscan_config, param, value) == False ) {
                /* parse VFS module specific configuration values */
		if ( StrCaseCmp("clamd socket name", param) == 0) {
#ifdef LIBCLAMAV
			DEBUG(3, ("clamd socket name not supported when linked against lib clamav\n"));
#else
			fstrcpy(clamd_socket_name, value);
			DEBUG(3, ("clamd socket name is %s\n", clamd_socket_name));
#endif

#ifdef LIBCLAMAV
		} else if ( StrCaseCmp("libclamav max files in archive", param) == 0 ) {
			/* sanity check? */
			clamav_limits.maxfiles = atoi(value);
			DEBUG(3, ("libclamav maxfiles limit is: %i\n", clamav_limits.maxfiles));
		} else if ( StrCaseCmp("libclamav max archived file size", param) == 0) {
			/* sanity check? */
			clamav_limits.maxfilesize = atol(value);
			DEBUG(3, ("libclamav max archived files limit is: %li\n", clamav_limits.maxfilesize));
		} else if ( StrCaseCmp("libclamav max recursion level", param) == 0 ) {
			/* sanity check? */
			clamav_limits.maxreclevel = atoi(value);
			DEBUG(3, ("libclamav max recursion level limit is: %i\n", clamav_limits.maxreclevel));
#else
		} else if ( StrCaseCmp("scan archives", param) == 0 ) {
			set_boolean(value, &scanarchives);
			DEBUG(3, ("scan archives: %d\n", scanarchives));
#endif
		} else
        	        DEBUG(3, ("unknown parameter: %s\n", param));
	}

        return True;
}

static bool do_section(const char *section, void *userdata)
{
        /* simply return true, there's only one section :-) */
        return True;
}




/* Implementation of vfs_ops.  */

#if (SMB_VFS_INTERFACE_VERSION >= 21)
static int vscan_connect(vfs_handle_struct *handle,  const char *svc, const char *user)
#elif (SMB_VFS_INTERFACE_VERSION >= 6)
static int vscan_connect(vfs_handle_struct *handle, connection_struct *conn, const char *svc, const char *user)
#else
static int vscan_connect(struct connection_struct *conn, PROTOTYPE_CONST char *svc, PROTOTYPE_CONST char *user)
#endif
{
        fstring config_file;            /* location of config file, either
                                           PARAMCONF or as set via vfs options
                                        */

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

       /* set default values */
        set_common_default_settings(&vscan_config);

#ifdef LIBCLAMAV
	memset(&clamav_limits, 0, sizeof(struct cl_limits));

	clamav_limits.maxfiles = VSCAN_CL_MAXFILES;
	clamav_limits.maxfilesize = VSCAN_CL_MAXFILESIZE;
	clamav_limits.maxreclevel = VSCAN_CL_MAXRECLEVEL;
#else
	/* set default value for scanning archives */
	scanarchives = VSCAN_SCAN_ARCHIVES;

        /* name of clamd socket */
        fstrcpy(clamd_socket_name, VSCAN_CLAMD_SOCKET_NAME);
#endif

	vscan_syslog("INFO: connect to service %s by user %s", 
	       svc, user);

	#if (SAMBA_VERSION_MAJOR==2 && SAMBA_VERSION_RELEASE>=4) || SAMBA_VERSION_MAJOR==3
	 #if (SMB_VFS_INTERFACE_VERSION >= 21)
	  fstrcpy(config_file, get_configuration_file(handle->conn, VSCAN_MODULE_STR, PARAMCONF));
	 #else 
          fstrcpy(config_file, get_configuration_file(conn, VSCAN_MODULE_STR, PARAMCONF));
	 #endif
          DEBUG(3, ("configuration file is: %s\n", config_file));

          retval = pm_process(config_file, do_section, do_parameter, NULL);
          DEBUG(10, ("pm_process returned %d\n", retval));

          /* FIXME: this is lame! */
          verbose_file_logging = vscan_config.common.verbose_file_logging;
          send_warning_message = vscan_config.common.send_warning_message;

	  if (!retval) vscan_syslog("ERROR: could not parse configuration file '%s'. File not found or not read-able. Using compiled-in defaults", config_file);
	#endif

#ifdef LIBCLAMAV
	/* initialise lib clamav */
	vscan_clamav_lib_init();
#endif

        /* initialise lrufiles list */
        DEBUG(5, ("init lrufiles list\n"));
        lrufiles_init(vscan_config.common.max_lrufiles, vscan_config.common.lrufiles_invalidate_time);

	/* initialise filetype */
	DEBUG(5, ("init file type\n"));
	filetype_init(0, vscan_config.common.exclude_file_types);

	/* initialise file regexp */
        DEBUG(5, ("init file regexp\n"));
	fileregexp_init(vscan_config.common.exclude_file_regexp);

	#if (SMB_VFS_INTERFACE_VERSION >= 21)
	 return SMB_VFS_NEXT_CONNECT(handle, svc, user);	
	#elif (SMB_VFS_INTERFACE_VERSION >= 6)
	 return SMB_VFS_NEXT_CONNECT(handle, conn, svc, user);
	#else
	 return default_vfs_ops.connect(conn, svc, user);
	#endif

}

#if (SMB_VFS_INTERFACE_VERSION >= 21)
static void vscan_disconnect(vfs_handle_struct *handle)
#elif (SMB_VFS_INTERFACE_VERSION >= 6)
static void vscan_disconnect(vfs_handle_struct *handle, connection_struct *conn)
#else/* Samba 3.0 alphaX */
static void vscan_disconnect(struct connection_struct *conn)
#endif
{

	vscan_syslog("INFO: disconnected");

#ifdef LIBCLAMAV
	vscan_clamav_lib_done();
#endif

        lrufiles_destroy_all();
	filetype_close();

#if (SMB_VFS_INTERFACE_VERSION >= 21)
	SMB_VFS_NEXT_DISCONNECT(handle);
#elif (SMB_VFS_INTERFACE_VERSION >= 6)
	SMB_VFS_NEXT_DISCONNECT(handle, conn);
#else
	default_vfs_ops.disconnect(conn);
#endif
}

#if (SMB_VFS_INTERFACE_VERSION >= 21)
static int vscan_open(vfs_handle_struct *handle, const char *fname, files_struct *fsp, int flags, mode_t mode)
#elif (SMB_VFS_INTERFACE_VERSION >= 6)
static int vscan_open(vfs_handle_struct *handle, connection_struct *conn, const char *fname, int flags, mode_t mode)
#else
static int vscan_open(struct connection_struct *conn, PROTOTYPE_CONST char *fname, int flags, mode_t mode)
#endif
{
	SMB_STRUCT_STAT stat_buf;
	pstring filepath;

	/* Assemble complete file path */
	#if (SMB_VFS_INTERFACE_VERSION >= 21)
		pstrcpy(filepath, handle->conn->connectpath);
	#else
		pstrcpy(filepath, conn->connectpath);
	#endif
	pstrcat(filepath, "/");
	pstrcat(filepath, fname);


        /* scan files while opening? */
        if ( !vscan_config.common.scan_on_open ) {
                DEBUG(3, ("samba-vscan - open: File '%s' not scanned as scan_on_open is not set\n", fname));
        }
#if (SMB_VFS_INTERFACE_VERSION >= 21)
	if ( (SMB_VFS_NEXT_STAT(handle, fname, &stat_buf)) != 0 ) {    /* an error occured */ 
#elif (SMB_VFS_INTERFACE_VERSION >= 6)
	else if ( (SMB_VFS_NEXT_STAT(handle, conn, fname, &stat_buf)) != 0 ) {    /* an error occured */ 
#else
	else if ( (default_vfs_ops.stat(conn, fname, &stat_buf)) != 0 ) {    /* an error occured */ 
#endif
		if ( errno == ENOENT ) {
			if ( verbose_file_logging )
				vscan_syslog("INFO: File %s not found! Not scanned!", fname);
		}
		else {
			vscan_syslog("ERROR: File %s not readable or an error occured", fname);
		}
	}
	else if ( S_ISDIR(stat_buf.st_mode) ) { 	/* is it a directory? */
		if ( verbose_file_logging )
			vscan_syslog("INFO: File %s is a directory! Not scanned!", fname);
	}
	else if ( ( stat_buf.st_size > vscan_config.common.max_size ) && ( vscan_config.common.max_size > 0 ) ) { /* file is too large */
		if ( vscan_config.common.verbose_file_logging )
			vscan_syslog("INFO: File %s is larger than specified maximum file size! Not scanned!", fname);
	}
	else if ( stat_buf.st_size == 0 ) { /* do not scan empty files */
		if ( vscan_config.common.verbose_file_logging )
			vscan_syslog("INFO: File %s has size zero! Not scanned!", fname);
	}
	else if ( fileregexp_skipscan(filepath) == VSCAN_FR_SKIP_SCAN ) {
		if ( vscan_config.common.verbose_file_logging )
			vscan_syslog("INFO: File '%s' not scanned as file is machted by exclude regexp", filepath);
	}
	else if ( filetype_skipscan(filepath) == VSCAN_FT_SKIP_SCAN ) {
		if ( verbose_file_logging )
			vscan_syslog("INFO: File '%s' not scanned as file type is on exclude list", filepath);
	} else
	{
		char client_ip[CLIENT_IP_SIZE];
		int must_be_checked;

#if (SMB_VFS_INTERFACE_VERSION >= 21)
		safe_strcpy(client_ip, handle->conn->client_address, CLIENT_IP_SIZE - 1);
#else		
		safe_strcpy(client_ip, conn->client_address, CLIENT_IP_SIZE -1);
#endif
                /* must file actually be scanned? */
                must_be_checked = lrufiles_must_be_checked(filepath, stat_buf.st_mtime);
                if ( must_be_checked == VSCAN_LRU_DENY_ACCESS ) {
                        /* file has already been checked and marked as infected */
                        /* deny access */
                        if ( vscan_config.common.verbose_file_logging )
                                vscan_syslog("INFO: File '%s' has already been scanned and marked as infected. Not scanned any more. Access denied", filepath);

			/* deny access */
                        errno = EACCES;
                        return -1;
                } else if ( must_be_checked == VSCAN_LRU_GRANT_ACCESS )  {
                        /* file has already been checked, not marked as infected and not modified */
                        if ( vscan_config.common.verbose_file_logging )
                                vscan_syslog("INFO: File '%s' has already been scanned, not marked as infected and not modified. Not scanned anymore. Access granted", filepath);
                }
		else {
                        /* ok, we must check the file */
			int retval;

#ifdef LIBCLAMAV
			retval = vscan_clamav_lib_scanfile(filepath, client_ip);
#else	/* LIBCLAMAV	*/
			int sockfd;

			/* open socket */
			sockfd = vscan_clamav_init();
	                if ( sockfd == VSCAN_SCAN_ERROR ) {
				if( vscan_config.common.deny_access_on_error ) {
		                        /* an error occured - can not communicate to daemon - deny access */
					vscan_syslog("ERROR: can not communicate to daemon - access denied");
					errno = EACCES;
					return -1;
				}
				vscan_syslog("ERROR: can not communicate to daemon - Not scanned!");
				retval = 3;	/* Access allowed, not scanned */
			} else
			{
				/* scan file */
				retval = vscan_clamav_scanfile(sockfd, filepath, client_ip);
				vscan_clamav_end(sockfd);
			}
#endif 
			if ( retval == VSCAN_SCAN_OK ) {
                                /* file is clean, add to lrufiles */
                                lrufiles_add(filepath, stat_buf.st_mtime, False);
			}
			else if ( retval == VSCAN_SCAN_VIRUS_FOUND ) {
				/* virus found */
				/* do action ... */
#if (SMB_VFS_INTERFACE_VERSION >= 21)
				vscan_do_infected_file_action(handle, handle->conn, filepath, vscan_config.common.quarantine_dir, vscan_config.common.quarantine_prefix, vscan_config.common.infected_file_action);
#elif (SMB_VFS_INTERFACE_VERSION >= 6)
				vscan_do_infected_file_action(handle, conn, filepath, vscan_config.common.quarantine_dir, vscan_config.common.quarantine_prefix, vscan_config.common.infected_file_action);
#else
				vscan_do_infected_file_action(&default_vfs_ops, conn, filepath, vscan_config.common.quarantine_dir, vscan_config.common.quarantine_prefix, vscan_config.common.infected_file_action);
#endif

                                /* add/update file. mark file as infected! */
                                lrufiles_add(filepath, stat_buf.st_mtime, True);

				/* virus found, deny acces */
				errno = EACCES; 
				return -1;
			}
			else if ( retval == VSCAN_SCAN_MINOR_ERROR ) {
				/* to be safe, remove file from lrufiles */
				lrufiles_delete(filepath);

				if( vscan_config.common.deny_access_on_minor_error ) {
					/* a minor error occured - deny access */
					vscan_syslog("ERROR: daemon failed with a minor error - access to file %s denied", fname);

					/* deny access */
					errno = EACCES;
					return -1;
				}
				/* a minor error occured - Not scanned */
				vscan_syslog("ERROR: daemon failed with a minor error - file %s Not scanned!", fname);
                        } else if ( retval == VSCAN_SCAN_ERROR ) {
				/* to be safe, remove file from lrufiles */
				lrufiles_delete(filepath);

				if( vscan_config.common.deny_access_on_error ) {
					/* an error occured - can not communicate to daemon - deny access */
					vscan_syslog("ERROR: can not communicate to clamd - access to file %s denied", fname);

					/* deny access */
					errno = EACCES;
					return -1;
				}
				/* an error occured - can not communicate to daemon - Not scanned */
				vscan_syslog("ERROR: can not communicate to clamd - file %s Not scanned!", fname);
			}
		}
	}
#if (SMB_VFS_INTERFACE_VERSION >= 21)
	return SMB_VFS_NEXT_OPEN(handle, fname, fsp, flags, mode);
#elif (SMB_VFS_INTERFACE_VERSION >= 6)
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
	SMB_STRUCT_STAT stat_buf;
	pstring filepath;
        int retval = 0, rv = 0;
	char client_ip[CLIENT_IP_SIZE];

        /* First close the file */
#if (SMB_VFS_INTERFACE_VERSION >= 6)
        retval = SMB_VFS_NEXT_CLOSE(handle, fsp);
#else
        retval = default_vfs_ops.close(fsp, fd);
#endif

        /* get the file name */
        pstrcpy(filepath, fsp->conn->connectpath);
        pstrcat(filepath, "/");
        pstrcat(filepath, fsp->fsp_name);

        if ( !vscan_config.common.scan_on_close ) {
                DEBUG(3, ("samba-vscan - close: File '%s' not scanned as scan_on_close is not set\n", fsp->fsp_name));
        }
        /* Don't scan directorys */
        else if ( fsp->is_directory )
		DEBUG(10, ("don't scan directory\n"));
	/* Don't scan files which have not been modified */
	else if ( !fsp->modified ) {
                if ( vscan_config.common.verbose_file_logging ) 
                        vscan_syslog("INFO: file %s was not modified - not scanned", filepath);

	}
        /* dont' scan file which matches exclude regexp */
        else if ( fileregexp_skipscan(filepath) == VSCAN_FR_SKIP_SCAN ) {
                if ( vscan_config.common.verbose_file_logging )
                        vscan_syslog("INFO: file '%s' not scanned as file is machted by exclude regexp", filepath);
        }
	/* don't scan files which are in the list of exclude file types */
	else if ( filetype_skipscan(filepath) == VSCAN_FT_SKIP_SCAN ) {
                if ( vscan_config.common.verbose_file_logging )
                        vscan_syslog("INFO: File '%s' not scanned as file type is on exclude list", filepath);
	}

#if (SMB_VFS_INTERFACE_VERSION >= 21)
	else if ( (SMB_VFS_NEXT_STAT(handle, fsp->fsp_name, &stat_buf)) != 0 ) {    /* an error occured */ 
#elif (SMB_VFS_INTERFACE_VERSION >= 6)
	else if ( (SMB_VFS_NEXT_STAT(handle, handle->conn, fsp->fsp_name, &stat_buf)) != 0 ) {    /* an error occured */ 
#else
	else if ( (default_vfs_ops.stat(fsp->conn, fsp->fsp_name, &stat_buf)) != 0 ) {    /* an error occured */ 
#endif
		if( errno == ENOENT) {
			if ( vscan_config.common.verbose_file_logging )
				vscan_syslog("INFO: File %s not found! Not scanned!", fsp->fsp_name);
		} else {
			vscan_syslog("ERROR: File %s not readable or an error occured", fsp->fsp_name);
		}
		rv = 3; /* FIXME: due to code re-org this should no longer be needed */
	}
	else {
		safe_strcpy(client_ip, fsp->conn->client_address, CLIENT_IP_SIZE -1);
#ifdef LIBCLAMAV
		/* scan only file, do nothing */
		rv = vscan_clamav_lib_scanfile(filepath, client_ip);
#else	/* LIBCLAMAV */
		{
			int sockfd;
			sockfd = vscan_clamav_init();
                	/* Errors are written from vscan_clamav_init()	*/
			if ( sockfd < 0 )
				return retval;
			/* scan only file, do nothing */
                	rv = vscan_clamav_scanfile(sockfd, filepath, client_ip);
                	vscan_clamav_end(sockfd);
		}
#endif	/* LIBCLAMAV */

		if ( rv == VSCAN_SCAN_VIRUS_FOUND ) {
			/* virus was found */
#if (SMB_VFS_INTERFACE_VERSION >= 6)
			vscan_do_infected_file_action(handle, fsp->conn, filepath, vscan_config.common.quarantine_dir, vscan_config.common.quarantine_prefix, vscan_config.common.infected_file_action);
#else
			vscan_do_infected_file_action(&default_vfs_ops, fsp->conn, filepath, vscan_config.common.quarantine_dir, vscan_config.common.quarantine_prefix, vscan_config.common.infected_file_action);
#endif
			/* add/update file, mark file as infected! */
			lrufiles_add(filepath, stat_buf.st_mtime, True);
		}
		else if( rv == VSCAN_SCAN_OK ) {
			/* add/update file, mark file as clean! */
			lrufiles_add(filepath, stat_buf.st_mtime, False);
		}
		else {
			/* to be save, delete file from lrufiles */
			lrufiles_delete(filepath);
		}
	}
	return retval;
}


#if (SMB_VFS_INTERFACE_VERSION >= 6)
/* Samba 3.0 */
NTSTATUS init_samba_module(void)
{
	NTSTATUS ret;
	
	ret = smb_register_vfs(SMB_VFS_INTERFACE_VERSION, VSCAN_MODULE_STR, vscan_ops);
	openlog("smbd_"VSCAN_MODULE_STR, LOG_PID, SYSLOG_FACILITY);
	vscan_syslog("samba-vscan (%s) registered (Samba 3.0), (c) by Rainer Link, OpenAntiVirus.org", module_id);
	DEBUG(5,("samba-vscan (%s) registered (Samba 3.0), (c) by Rainer Link, OpenAntiVirus.org\n", module_id));
	
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

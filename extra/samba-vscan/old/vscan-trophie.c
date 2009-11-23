/* 
 * $Id: vscan-trophie.c,v 1.1 2001/11/18 14:44:31 reniar Exp $
 *
 * virusscanning VFS module for samba.  Log infected files via syslog
 * facility and block access. A running Trophie daemon is needed.
 *
 * Copyright (C) Rainer Link, SuSE GmbH <link@suse.de>, 2001
 *                            OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * general source code review by Thomas Biege, SuSE GmbH <thomas@suse.de>, 2001 
 * 
 * based on the audit VFS module by
 * Copyright (C) Tim Potter, 1999-2000
 *
 * based on a Trophie sample application by
 * Copyright (C) Vanja Hrustic, 2001
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

#include "config.h"

#include <stdio.h>
#include <sys/stat.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>


#ifdef HAVE_UTIME_H
#include <utime.h>
#endif
#ifdef HAVE_DIRENT_H
#include <dirent.h>
#endif
#include <syslog.h>
#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif
#include <errno.h>
#include <string.h>
#include <includes.h>
#include <vfs.h>

#include <unistd.h>
#include <string.h>


#ifndef SYSLOG_FACILITY
#define SYSLOG_FACILITY   LOG_USER
#endif

#ifndef SYSLOG_PRIORITY
#define SYSLOG_PRIORITY   LOG_NOTICE
#endif

#ifndef bool
typedef int bool;
#endif 

#ifndef FALSE
# define FALSE	0
#endif /* ! FALSE */
#ifndef TRUE
# define TRUE	1
#endif /* ! TRUE */

/* Configuration Section :-) */

/* which samba version is this VFS module compiled for 
 * Set SAMBA_VERSION_MINOR to 2 if you're using Samba 2.2.2 or
 * to 1 if you're using Samba 2.2.1[a] or 0 for Samba 2.2.0[a] */

#ifndef SAMBA_VERSION_MINOR
# define SAMBA_VERSION_MINOR 2
#endif

/* 0 = log only infected file, 1 = log every file access */

#ifndef VERBOSE_FILE_LOGGING
# define VERBOSE_FILE_LOGGING 0 
#endif


/* Sophie stuff */
#define TROPHIE_SOCKET_NAME	"/var/run/trophie"	

/* End Configuration Section */

int sock;
int bread;
struct sockaddr_un server;
bool sock_ok = TRUE;

/* module version */
static const char module_id[]="$Revision: 1.1 $";


/* Function prototypes */

int vscan_connect(struct connection_struct *conn, char *svc, char *user);
void vscan_disconnect(struct connection_struct *conn);

int vscan_open(struct connection_struct *conn, char *fname, int flags, mode_t mode);

/* VFS operations */

extern struct vfs_ops default_vfs_ops;   /* For passthrough operation */

struct vfs_ops vscan_ops = {
    
	/* Disk operations */

	vscan_connect,
	vscan_disconnect,
	NULL,                     /* disk free */

	/* Directory operations */

	NULL,
	NULL,                     /* readdir */
	NULL,
	NULL,
	NULL,                     /* closedir */

	/* File operations */

	vscan_open,
	NULL,
	NULL,                     /* read  */
	NULL,                     /* write */
	NULL,                     /* lseek */
	NULL,
	NULL,                     /* fsync */
	NULL,                     /* stat  */
	NULL,                     /* fstat */
	NULL,                     /* lstat */
	NULL,
	NULL,
	NULL,                     /* chown */
	NULL,                     /* chdir */
	NULL,                     /* getwd */
	NULL,                     /* utime */
	NULL,                     /* ftruncate */
	NULL,                     /* lock */
	NULL,                     /* fget_nt_acl */
	NULL,                     /* get_nt_acl */
	NULL,                     /* fset_nt_acl */
	NULL                      /* set_nt_acl */
};




/* VFS initialisation function.  Return initialised vfs_ops structure
   back to SAMBA. */

#if SAMBA_VERSION_MINOR==2
struct vfs_ops *vfs_init(int* Version, struct vfs_ops *ops)
#elif SAMBA_VERSION_MINOR==1
struct vfs_ops *vfs_module_init(int *vfs_version)
#else
struct vfs_ops *vfs_init(int *vfs_version)
#endif
{
	openlog("smbd_vscan_trophie", LOG_PID, SYSLOG_FACILITY);

	#if SAMBA_VERSION_MINOR==2
        *Version = SMB_VFS_INTERFACE_VERSION;
        syslog(SYSLOG_PRIORITY, "VFS_INIT: vscan_ops loaded - %s\n", module_id); 
	#else
	*vfs_version = SMB_VFS_INTERFACE_VERSION;
	syslog(SYSLOG_PRIORITY, "VFS_INIT: &vscan_ops: 0x%8.8x - %s\n", 
	       &vscan_ops, module_id);
	#endif

	return(&vscan_ops);
}

/* Implementation of vfs_ops.  Pass everything on to the default
   operation but log event first. */

int vscan_connect(struct connection_struct *conn, char *svc, char *user)
{
	syslog(SYSLOG_PRIORITY, "connect to service %s by user %s\n", 
	       svc, user);

	syslog(SYSLOG_PRIORITY, "connecting to Trophie socket");
	sock = socket(AF_UNIX, SOCK_STREAM, 0);
	if (sock < 0)
	{
		syslog(SYSLOG_PRIORITY, "creating socket failed!");
		sock_ok = FALSE;
	}
	
	if (sock_ok)
	{
	        server.sun_family = AF_UNIX;
       		strncpy(server.sun_path, TROPHIE_SOCKET_NAME, sizeof(server.sun_path)-1);
        	if (connect(sock, (struct sockaddr *) &server, sizeof(struct sockaddr_un)) < 0)
        	{
                	syslog(SYSLOG_PRIORITY, "connecting to socket failed");
                	sock_ok = FALSE;
        	}
	}

	if (sock_ok)
		syslog(SYSLOG_PRIORITY, "connection to Trophie established");

	return default_vfs_ops.connect(conn, svc, user);
}

void vscan_disconnect(struct connection_struct *conn)
{
	if (sock_ok)
	{
		close(sock);
		syslog(SYSLOG_PRIORITY, "socket to Trophie closed!");
	}
        syslog(SYSLOG_PRIORITY, "disconnected\n");

	default_vfs_ops.disconnect(conn);
}


int vscan_open(struct connection_struct *conn, char *fname, int flags, mode_t mode)
{

/*        char path[MAXPATHLEN];   
	  seems Sophie can't handle more then 512.
*/
	char path[512];
        char buf[512];

// take adding '\n' later into account
	size_t fname_size = strlen(fname)+2;


	if (sock_ok)
	{
		memset(path, 0, sizeof(path));

// avoid a possible integer overflow if fname is very large

		if ( fname_size < 0 || fname_size > sizeof(path) )
		{
			syslog(SYSLOG_PRIORITY, "Error: Filename too large. Calling default VFS open function");
			return default_vfs_ops.open(conn, fname, flags, mode);
		}		

		strncpy(path, fname, sizeof(path)-2);

//  Sophie needs '\n'. How to deal with a file name, which contains '\n'
//  somehwere in the file name?

		path[strlen(path)] = '\n';


        	if (write(sock, path, strlen(path)) < 0)
               		syslog(SYSLOG_PRIORITY, "writing to Trophie socket failed!");
		else 
		{
			memset(buf, 0, sizeof(buf));
	        	if ((bread = read(sock, buf, sizeof(buf))) > 0)
			{
                		if (strchr(buf, '\n'))
                        		*strchr(buf, '\n') = '\0';

                		if (buf[0] == '1') {
					/* Hehe ... */
					char *virusname = buf+2;

                        		syslog(SYSLOG_PRIORITY, "FILE %s INFECTED WITH %s VIRUS. Access denied!", fname, virusname);
					return(-1);
				 }
				 #if VERBOSE_FILE_LOGGING==1
				 else if (!strncmp(buf, "-1", 2))
                        		syslog(SYSLOG_PRIORITY, "FILE [%s] NOT FOUND, OR ERROR OCCURED (-1 received)", fname);
                		 else
                        		syslog(SYSLOG_PRIORITY, "FILE NOT INFECTED: [%s]\n", fname);
				 #endif
        		}
			else
	        	{
                		syslog(SYSLOG_PRIORITY, "Ouch! read() from the socket failed!");
        		}
		}
	}

	return default_vfs_ops.open(conn, fname, flags, mode);

}



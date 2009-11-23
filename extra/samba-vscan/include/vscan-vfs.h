#ifndef __VSCAN_VFS_H_
#define __VSCAN_VFS_H_


#if (SMB_VFS_INTERFACE_VERSION >= 6)
 static int vscan_connect(vfs_handle_struct *handle, connection_struct *conn, const char *svc, const char *user); 
 static void vscan_disconnect(vfs_handle_struct *handle, connection_struct *conn);
 static int vscan_open(vfs_handle_struct *handle, connection_struct *conn, const char *fname, 
 int flags, mode_t mode);
 static int vscan_close(vfs_handle_struct *handle, files_struct *fsp, int fd);
#else
 #if (SAMBA_VERSION_MAJOR==3) || (SAMBA_VERSION_RELEASE>=4)
 #define PROTOTYPE_CONST const
 #else
 #define PROTOTYPE_CONST
 #endif
 static int vscan_connect(struct connection_struct *conn, PROTOTYPE_CONST char *svc, PROTOTYPE_CONST char *user); 
 static void vscan_disconnect(struct connection_struct *conn);
 static int vscan_open(struct connection_struct *conn, PROTOTYPE_CONST char *fname, 
 int flags, mode_t mode);
 static int vscan_close(struct files_struct *fsp, int fd);
#endif /*  #if (SMB_VFS_INTERFACE_VERSION >= 6) */


/* VFS operations */

#if !(SMB_VFS_INTERFACE_VERSION >= 6)
 #if SAMBA_VERSION_MAJOR!=3
 /* Samba 2.2.x */
 extern struct vfs_ops default_vfs_ops;   /* For passthrough operation */
 #else
 /* Samba 3.0 alphaX */
 static struct vfs_ops default_vfs_ops;   /* For passthrough operation */
 static struct smb_vfs_handle_struct *vscan_handle; /* use skel_handle->data
 for storing per-instance private data */
 #endif
#endif

#if SAMBA_VERSION_MAJOR!=3 
 /* Samba 2.2.x */
 #if SAMBA_VERSION_RELEASE>=4
 /* Samba 2.2.4 */
 struct vfs_ops vscan_ops = {
    
	/* Disk operations */

	vscan_connect,			/* connect */
	vscan_disconnect,		/* disconnect */
	NULL,				/* disk free */

	/* Directory operations */

	NULL,				/* opendir */
	NULL,				/* readdir */
	NULL,				/* mkdir */
	NULL,				/* rmdir */
	NULL,				/* closedir */

	/* File operations */

	vscan_open,			/* open */
	vscan_close,			/* close */
	NULL,				/* read  */
	NULL,				/* write */
	NULL,				/* lseek */
	NULL,				/* rename */
	NULL,				/* fsync */
	NULL,				/* stat  */
	NULL,				/* fstat */
	NULL,				/* lstat */
	NULL,				/* unlink */
	NULL,				/* chmod */
	NULL,				/* fchmod */
	NULL,				/* chown */
	NULL,				/* fchown */
	NULL,				/* chdir */
	NULL,				/* getwd */
	NULL,				/* utime */
	NULL,				/* ftruncate */
	NULL,				/* lock */
	NULL,				/* symlink */
	NULL,				/* readlink */
	NULL,				/* link */
	NULL,				/* mknod */
	NULL,				/* realpath */
	NULL,				/* fget_nt_acl */
	NULL,				/* get_nt_acl */
	NULL,				/* fset_nt_acl */
	NULL,				/* set_nt_acl */

	NULL,				/* chmod_acl */
	NULL,				/* fchmod_acl */

	NULL,				/* sys_acl_get_entry */
	NULL,				/* sys_acl_get_tag_type */
	NULL,				/* sys_acl_get_permset */
	NULL,				/* sys_acl_get_qualifier */
	NULL,				/* sys_acl_get_file */
	NULL,				/* sys_acl_get_fd */
	NULL,				/* sys_acl_clear_perms */
	NULL,				/* sys_acl_add_perm */
	NULL,				/* sys_acl_to_text */
	NULL,				/* sys_acl_init */
	NULL,				/* sys_acl_create_entry */
	NULL,				/* sys_acl_set_tag_type */
	NULL,				/* sys_acl_set_qualifier */
	NULL,				/* sys_acl_set_permset */
	NULL,				/* sys_acl_valid */
	NULL,				/* sys_acl_set_file */
	NULL,				/* sys_acl_set_fd */
	NULL,				/* sys_acl_delete_def_file */
	NULL,				/* sys_acl_get_perm */
	NULL,				/* sys_acl_free_text */
	NULL,				/* sys_acl_free_acl */
	NULL				/* sys_acl_free_qualifier */
 };
 #else
 /* Samba 2.2.3-2.2.0 */
 struct vfs_ops vscan_ops = {
    
	/* Disk operations */

	vscan_connect,		  /* connect */
	vscan_disconnect,	  /* disconnect */
	NULL,                     /* disk free */

	/* Directory operations */

	NULL,			  /* opendir */
	NULL,                     /* readdir */
	NULL,			  /* mkdir */
	NULL,			  /* rmdir */	
	NULL,                     /* closedir */

	/* File operations */

	vscan_open,		  /* open  */
	vscan_close,		  /* close */
	NULL,                     /* read  */
	NULL,                     /* write */
	NULL,                     /* lseek */
	NULL,			  /* rname */
	NULL,                     /* fsync */
	NULL,                     /* stat  */
	NULL,                     /* fstat */
	NULL,                     /* lstat */
	NULL,			  /* unlink */
	NULL,			  /* chmod */
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
 #endif
#else
 /* Samba 3.0 alphaX */
 static vfs_op_tuple vscan_ops[] = {

	/* Disk operations */
	{vscan_connect,		SMB_VFS_OP_CONNECT,	SMB_VFS_LAYER_TRANSPARENT},
	{vscan_disconnect,	SMB_VFS_OP_DISCONNECT,	SMB_VFS_LAYER_TRANSPARENT},

	/* File operations */
	{vscan_open,		SMB_VFS_OP_OPEN,	SMB_VFS_LAYER_TRANSPARENT},
	{vscan_close,		SMB_VFS_OP_CLOSE,	SMB_VFS_LAYER_TRANSPARENT},

	/* Finish VFS operations definition */
	{NULL, 			SMB_VFS_OP_NOOP,	SMB_VFS_LAYER_NOOP}
 };
#endif 

#endif /* __VSCAN-VFS_H_ */

#ifndef __VSCAN_GLOBAL_H_
#define __VSCAN_GLOBAL_H_

#include <includes.h>

#include "vscan-config.h"

#include "vscan-quarantine.h"
#include "vscan-context.h"
#include "vscan-functions.h"
#include "vscan-fileaccesslog.h"
#include "vscan-message.h"


#define CLIENT_IP_SIZE 18

NTSTATUS vscan_init_oav(void);



int vscan_call_open(VSCAN_CONTEXT *context);
int vscan_call_scan(VSCAN_CONTEXT *context, const char *fname, const char *newname, int flags, mode_t mode);
int vscan_call_close(VSCAN_CONTEXT *context);
VSCAN_CONTEXT *vscan_create_context(vfs_handle_struct *handle);
void vscan_destroy_context(VSCAN_CONTEXT *context);

int vscan_global_config(VSCAN_CONTEXT *context);
int vscan_private_config(VSCAN_CONTEXT *context);
bool vscan_on_open(VSCAN_CONTEXT *context);
bool vscan_on_close(VSCAN_CONTEXT *context);
bool vscan_on_sendfile(VSCAN_CONTEXT *context);
bool vscan_on_rename(VSCAN_CONTEXT *context);



/* Configuration Section :-) */

/* which samba version is this VFS module compiled for:
 * Set SAMBA_VERSION_MAJOR to 3 for Samba 3.0.x or
 * to 2 for Samba 2.2.x
 * Set SAMBA_VERSION_MINOR to 0 for Samba 3.0.x or
 * to 2 for Samba 2.2.x 
 * Set SAMBA_VERSION_RELEASE to 8 for Samba >= 2.2.8
 * Set it to 4 for Samba 2.2.4 - 2.2.7 
 * Set it to 2 if you're using Samba 2.2.2/2.2.3
 * Set it to 1 if you're using Samba 2.2.1[a] or 0 for Samba 2.2.0[a] 
 * If SAMBA_VERSION_MAJOR is set to 3, SAMBA_VERSION_RELEASE
 * is ignored!
 *
 * Per default, Samba >=2.2.8 is assumed!
*/

#ifndef SAMBA_VERSION_MAJOR
# define SAMBA_VERSION_MAJOR 2
#endif

#ifndef SAMBA_VERSION_MINOR
# define SAMBA_VERSION_MINOR 2 
#endif 

#ifndef SAMBA_VERSION_RELEASE
# define SAMBA_VERSION_RELEASE 8 
#endif 

#ifndef SYSLOG_FACILITY
#define SYSLOG_FACILITY   LOG_USER
#endif

#ifndef SYSLOG_PRIORITY
#define SYSLOG_PRIORITY   LOG_NOTICE
#endif

/* virus messages will be logged as SYSLOG_PRIORITY_ALERT */
#ifndef SYSLOG_PRIORITY_ALERT
#define SYSLOG_PRIORITY_ALERT   LOG_ERR
#endif






#endif /* __VSCAN_GLOBAL_H */

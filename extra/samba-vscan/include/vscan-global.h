#ifndef __VSCAN_GLOBAL_H_
#define __VSCAN_GLOBAL_H_

#include <includes.h>

#include "vscan-config.h"

#include "vscan-functions.h"
#include "vscan-fileaccesslog.h"
#include "vscan-message.h"
#include "vscan-quarantine.h"
#include "vscan-filetype.h"
#include "vscan-parameter.h"
#include "vscan-scan.h"
#include "vscan-fileregexp.h"

#define CLIENT_IP_SIZE 18


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

/* end configuration section */


#if (SMB_VFS_INTERFACE_VERSION < 6)
 #if (SAMBA_VERSION_MAJOR==3) || (SAMBA_VERSION_RELEASE>=4)
 #define PROTOTYPE_CONST const
 #else
 #define PROTOTYPE_CONST
 #endif
#endif



#endif /* __VSCAN_GLOBAL_H */

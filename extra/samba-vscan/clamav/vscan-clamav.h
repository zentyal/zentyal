#ifndef __VSCAN_CLAMAV_H_
#define __VSCAN_CLAMAV_H_

#include "vscan-global.h"
#include "vscan-clamav_core.h"

/* Configuration Section :-) */

/* default location of samba-style configuration file (needs Samba >= 2.2.4
 or Samba 3.0 */

#define PARAMCONF "/etc/samba/vscan-clamav.conf"

/* Clam AntiVirus (clamd) stuff:
   socket name of Clam daemon */
#define VSCAN_CLAMD_SOCKET_NAME      "/var/run/clamd"

#define VSCAN_SCAN_ARCHIVES True

/* Clam AntiVirus (libclamav) stuff:
   maximum number of files in archive */
#define VSCAN_CL_MAXFILES 1000
/* maximum archived file size (in bytes) */
#define VSCAN_CL_MAXFILESIZE 10485670
/* maximum recursion level */
#define VSCAN_CL_MAXRECLEVEL 5


/* End Configuration Section */

#endif /* __VSCAN_CLAMAV_H_ */ 

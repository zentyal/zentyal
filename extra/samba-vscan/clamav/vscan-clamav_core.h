#ifndef __VSCAN_CLAMAV_CORE_H_
#define __VSCAN_CLAMAV_CORE_H_

#include "vscan-clamav.h"

#ifdef LIBCLAMAV
/* load signature tree */
void vscan_clamav_lib_init();
/* cleanup signature tree */
void vscan_clamav_lib_done();
/* scans a file */
int vscan_clamav_lib_scanfile(char *scan_file, char *client_ip);

#else
/* opens socket */
int vscan_clamav_init(void);
/* closes socket */
void vscan_clamav_end(int sockfd);
/* scans a file */
int vscan_clamav_scanfile(int sockfd, char *scan_file, char *client_ip);

#endif

#endif /* __VSCAN_CLAMAV_CORE_H */

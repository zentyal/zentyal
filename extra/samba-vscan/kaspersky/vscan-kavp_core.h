
#ifndef __VSCAN_KAVP_CORE_H_
#define __VSCAN_KAVP_CORE_H_

int vscan_kavp_scanfile(char *scan_file, char* client_ip);
void vscan_kavp_init(void);
void vscan_kavp_end(void);

#ifdef HAVE_LIBKAVDC_BUILTIN
 #include "libkavdc/kavclient.h"
#else
 #include <kavclient.h>
#endif

#endif /*__VSCAN_KAVP_CORE_H_ */


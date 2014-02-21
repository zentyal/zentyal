#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <clamav.h>


MODULE = ClamAV::XS		PACKAGE = ClamAV::XS		

unsigned int
signatures()
PREINIT:
	int ret;
	const char *db_path;
	unsigned int sigs;
INIT:
	db_path = NULL;
	ret = 0;
	sigs = 0;
CODE:
	db_path = cl_retdbdir();
	if (db_path == NULL) {
		croak("Error getting clamav database directory");
	}
	ret = cl_countsigs(db_path, CL_COUNTSIGS_ALL, &sigs);
	if (ret != CL_SUCCESS) {
		croak("Error getting signature count: %s", cl_strerror(ret));
	}
	RETVAL = sigs;
OUTPUT:
	RETVAL

#ifndef __ZAVS_CLAMAV_H__
#define __ZAVS_CLAMAV_H__

#include "zavs_param.h"

enum cl_engine_field;

#define ZAVS_SCAN_CLEAN         1
#define ZAVS_SCAN_INFECTED      2
#define ZAVS_SCAN_ERROR         3

void zavs_clamav_lib_init(const zavs_config_struct *config);
void zavs_clamav_lib_done();
int zavs_clamav_lib_scanfile(const char *filepath, const zavs_config_struct *config);
void zavs_set_engine_option(enum cl_engine_field field, long long value);

#endif

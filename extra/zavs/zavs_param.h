#ifndef __ZAVS_PARAM_H_
#define __ZAVS_PARAM_H_

#include <stdbool.h>
#include <stdint.h>

#include <config.h>
#include <includes.h>

#include "zavs_quarantine.h"

// false = log only infected file, true = log every file access
#define ZAVS_VERBOSE_FILE_LOGGING false

// true = scan files on open
#define ZAVS_SCAN_ON_OPEN true

// true = scan files on close
#define ZAVS_SCAN_ON_CLOSE true

// true = deny access in case of virus scanning failure
#define ZAVS_DENY_ACCESS_ON_ERROR false

// true = send a warning message via window messenger service for viruses found
#define ZAVS_SEND_WARNING_MESSAGE true

// default infected file action
#define ZAVS_INFECTED_FILE_ACTION INFECTED_QUARANTINE

// default quarantine settings
#define ZAVS_QUARANTINE_DIRECTORY "/tmp"
#define ZAVS_QUARANTINE_PREFIX    "vir-"

// set default value for maximum lrufile entries
#define ZAVS_MAX_LRUFILES 100

// time after an entry is considered as expired
#define ZAVS_LRUFILES_INVALIDATE_TIME 5

// MIME-types of files to be exluded from scanning; that's an
// semi-colon seperated list
#define ZAVS_FT_EXCLUDE_LIST ""
#define ZAVS_FT_EXCLUDE_REGEXP ""

// This values are copied from libclamav defaults.h
#define ZAVS_CLAMAV_MAX_SCAN_SIZE     104857600
#define ZAVS_CLAMAV_MAX_FILE_SIZE     26214400
#define ZAVS_CLAMAV_MAX_REC_LEVEL     16
#define ZAVS_CLAMAV_MAX_FILES         10000

typedef struct {
    struct {
        bool verbose_file_logging;
        bool scan_on_open;
        bool scan_on_close;
        bool deny_access_on_error;
        bool send_warning_message;
        const char *quarantine_dir;
        const char *quarantine_prefix;
        int infected_file_action;
        int max_lrufiles;
        time_t lrufiles_invalidate_time;
        const char *exclude_file_types;
        const char *exclude_file_regexp;
    } common;
    struct {
        long long max_files;
        long long max_file_size;
        long long max_scan_size;
        long long max_recursion_level;
    } clamav_limits;
    void* specific;
} zavs_config_struct;

void zavs_parse_settings(vfs_handle_struct *handle, zavs_config_struct *c);

#endif

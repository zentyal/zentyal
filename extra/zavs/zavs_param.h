#ifndef __ZAVS_PARAM_H_
#define __ZAVS_PARAM_H_

#include <stdbool.h>
#include <stdint.h>

#include <config.h>
#include <includes.h>

#include "zavs_quarantine.h"

// Location of the Clam AntiVirus daemon socket
#define ZAVS_CLAMD_SOCKET_NAME "/var/run/clamd"

// false = log only infected file, true = log every file access
#define ZAVS_VERBOSE_FILE_LOGGING false

// if a file is bigger than ZAVS_MAX_SIZE it won't be scanned. Has to be
// specified in bytes! If it set to false, the file size check is disabled
#define ZAVS_MAX_SIZE false

// true = scan files on open
#define ZAVS_SCAN_ON_OPEN true

// true = scan files on close
#define ZAVS_SCAN_ON_CLOSE true

// true = deny access in case of virus scanning failure
#define ZAVS_DENY_ACCESS_ON_ERROR true

// true = deny access in case of minor virus scanning failure
#define ZAVS_DENY_ACCESS_ON_MINOR_ERROR true

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

typedef struct {
    struct {
        const char *clamd_socket;
        ssize_t max_size;
        bool verbose_file_logging;
        bool scan_on_open;
        bool scan_on_close;
        bool deny_access_on_error;
        bool deny_access_on_minor_error;
        bool send_warning_message;
        const char *quarantine_dir;
        const char *quarantine_prefix;
        int infected_file_action;
        int max_lrufiles;
        time_t lrufiles_invalidate_time;
        const char *exclude_file_types;
        const char *exclude_file_regexp;
    } common;
    void* specific;
} zavs_config_struct;

void zavs_parse_settings(vfs_handle_struct *handle, zavs_config_struct *c);

#endif

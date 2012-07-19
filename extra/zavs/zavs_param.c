#include <includes.h>
#include "zavs_param.h"
#include "zavs_log.h"
#include "zavs_quarantine.h"

void zavs_parse_settings(vfs_handle_struct *handle, zavs_config_struct *c)
{
    int snum = SNUM(handle->conn);

    // TODO Liberar la memoria de los punteros

    ZAVS_DEBUG(3, "Loading settings\n");

    c->common.clamd_socket = lp_parm_const_string(snum, "zavs", "clamd socket", ZAVS_CLAMD_SOCKET_NAME);
    ZAVS_DEBUG(3, "value for clamd socket: %s\n", c->common.clamd_socket);

    c->common.max_size = lp_parm_int(snum, "zavs", "max file size", ZAVS_MAX_SIZE);
    ZAVS_DEBUG(3, "value for max size: %d\n", c->common.max_size);

    c->common.verbose_file_logging = lp_parm_bool(snum, "zavs", "verbose file logging", ZAVS_VERBOSE_FILE_LOGGING);
    ZAVS_DEBUG(3, "value for verbose logging: %d\n", c->common.verbose_file_logging);

    c->common.scan_on_open = lp_parm_bool(snum, "zavs", "scan on open", ZAVS_SCAN_ON_OPEN);
    ZAVS_DEBUG(3, "value for scan on open: %d\n", c->common.scan_on_open);

    c->common.scan_on_close = lp_parm_bool(snum, "zavs", "scan on close", ZAVS_SCAN_ON_CLOSE);
    ZAVS_DEBUG(3, "value for scan on close: %d\n", c->common.scan_on_close);

    c->common.deny_access_on_error = lp_parm_bool(snum, "zavs", "deny access on error", ZAVS_DENY_ACCESS_ON_ERROR);
    ZAVS_DEBUG(3, "value for deny access on error: %d\n", c->common.deny_access_on_error);

    c->common.deny_access_on_minor_error = lp_parm_bool(snum, "zavs", "deny access on minor error", ZAVS_DENY_ACCESS_ON_MINOR_ERROR);
    ZAVS_DEBUG(3, "value for deny access on minor error: %d\n", c->common.deny_access_on_minor_error);

    c->common.send_warning_message = lp_parm_bool(snum, "zavs", "send warning message", ZAVS_SEND_WARNING_MESSAGE);
    ZAVS_DEBUG(3, "value for send warning message: %d\n", c->common.send_warning_message);

    c->common.infected_file_action = lp_parm_enum(snum, "zavs", "infected file action", infected_file_action_enum, ZAVS_INFECTED_FILE_ACTION);
    ZAVS_DEBUG(3, "value for infected file action: %d\n", c->common.infected_file_action);

    c->common.quarantine_dir = lp_parm_const_string(snum, "zavs", "quarantine dir",  ZAVS_QUARANTINE_DIRECTORY);
    ZAVS_DEBUG(3, "value for quarantine directory: %s\n", c->common.quarantine_dir);

    c->common.quarantine_prefix = lp_parm_const_string(snum, "zavs", "quarantine prefix", ZAVS_QUARANTINE_PREFIX);
    ZAVS_DEBUG(3, "value for quarantine prefix: %s\n", c->common.quarantine_prefix);

    c->common.max_lrufiles = lp_parm_int(snum, "zavs", "max lrufiles", ZAVS_MAX_LRUFILES);
    ZAVS_DEBUG(3, "value for max lrufile entries: %d\n", c->common.max_lrufiles);

    c->common.lrufiles_invalidate_time = lp_parm_int(snum, "zavs", "lrufiles invalidate time", ZAVS_LRUFILES_INVALIDATE_TIME);
    ZAVS_DEBUG(3, "value for invalidate time: %llu\n", (unsigned long long)c->common.lrufiles_invalidate_time);

    c->common.exclude_file_types = lp_parm_const_string(snum, "zavs", "exclude file types", ZAVS_FT_EXCLUDE_LIST);
    ZAVS_DEBUG(3, "value for file type exclude: %s\n", c->common.exclude_file_types);

    c->common.exclude_file_regexp = lp_parm_const_string(snum, "zavs", "exclude file regexp", ZAVS_FT_EXCLUDE_REGEXP);
    ZAVS_DEBUG(3, "value for file regexep exclude: %s\n", c->common.exclude_file_regexp);
}


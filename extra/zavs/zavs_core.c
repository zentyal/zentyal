#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include "zavs_core.h"
#include "zavs_log.h"
#include "zavs_param.h"
#include "zavs_fileaccesslog.h"
#include "zavs_filetype.h"
#include "zavs_fileregexp.h"

// This struct store the module configuration
static zavs_config_struct zavs_config;

void zavs_initialize(vfs_handle_struct *handle, const char *service, const char *user, const char *address)
{
    ZAVS_INFO("Zentyal AntiVirus for Samba (%s) connected (%s), (c) by eBox Technologies", MODULE_VERSION, SAMBA_VERSION);

    // Parse user specified settings
    zavs_parse_settings(handle, &zavs_config);

    // Set default value for scanning archives
	//scanarchives = 1;

    // Name of clamd socket
    //strncpy(clamd_socket_name, VSCAN_CLAMD_SOCKET_NAME);

	ZAVS_INFO("connect to service '%s' by user '%s' from '%s'", service, user, address);

    /* FIXME: this is lame! */
    //verbose_file_logging = vscan_config.common.verbose_file_logging;
    //send_warning_message = vscan_config.common.send_warning_message;

    //if (!retval) {
    //    ZAVS_ERROR("could not parse configuration file '%s'. File not found or not read-able. Using compiled-in defaults", config_file);
    //}

    // initialise lrufiles list
    ZAVS_DEBUG(5, "init lrufiles list\n");
    lrufiles_init(zavs_config.common.max_lrufiles, zavs_config.common.lrufiles_invalidate_time);

    // initialise filetype
    ZAVS_DEBUG(5, "init file type\n");
    filetype_init(0, zavs_config.common.exclude_file_types);

    // initialise file regexp
    ZAVS_DEBUG(5, "init file regexp\n");
    fileregexp_init(zavs_config.common.exclude_file_regexp);
}

void zavs_finalize(void)
{
    ZAVS_INFO("disconnected");
    lrufiles_destroy_all();
    filetype_close();
    fileregexp_close();
}


#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include "zavs_core.h"
#include "zavs_log.h"
#include "zavs_param.h"

// This struct store the module configuration
static zavs_config_struct zavs_config;

void zavs_initialize(vfs_handle_struct *handle, const char *service, const char *user, const char *address)
{
    // Location of config file, either PARAMCONF or as set via vfs options
    char config_file[512];

    int retval;

    ZAVS_INFO("Zentyal AntiVirus for Samba (%s) connected (%s), (c) by eBox Technologies", MODULE_VERSION, SAMBA_VERSION);

    // Set default value for configuration files
	strncpy(config_file, CONF_FILE, sizeof(config_file));

    // Parse user specified settings
    zavs_parse_settings(handle, &zavs_config);

    // Set default value for scanning archives
	//scanarchives = 1;

    // Name of clamd socket
    //strncpy(clamd_socket_name, VSCAN_CLAMD_SOCKET_NAME);

	ZAVS_INFO("connect to service '%s' by user '%s' from '%s'", service, user, address);

    //fstrcpy(config_file, get_configuration_file(handle->conn, VSCAN_MODULE_STR, PARAMCONF));
    //ZAVS_DEBUG(3, "configuration file is: %s\n", config_file);

    //retval = pm_process(config_file, do_section, do_parameter, NULL);
    //ZAVS_DEBUG(10, "pm_process returned %d\n", retval);

    /* FIXME: this is lame! */
    //verbose_file_logging = vscan_config.common.verbose_file_logging;
    //send_warning_message = vscan_config.common.send_warning_message;

    //if (!retval) {
    //    ZAVS_ERROR("could not parse configuration file '%s'. File not found or not read-able. Using compiled-in defaults", config_file);
    //}

    // initialise lrufiles list
    ZAVS_DEBUG(5, "init lrufiles list\n");
    //lrufiles_init(vscan_config.common.max_lrufiles, vscan_config.common.lrufiles_invalidate_time);

    // initialise filetype
    ZAVS_DEBUG(5, "init file type\n");
    //filetype_init(0, vscan_config.common.exclude_file_types);

    // initialise file regexp
    ZAVS_DEBUG(5, "init file regexp\n");
    //fileregexp_init(vscan_config.common.exclude_file_regexp);
}

void zavs_finalize(void)
{
    ZAVS_INFO("disconnected");
    //lrufiles_destroy_all();
    //filetype_close();
}


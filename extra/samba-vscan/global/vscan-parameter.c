/* $Id: vscan-parameter.c,v 1.1.2.8 2005/04/07 10:20:39 reniar Exp $ 
 *
 * Parses commonly-used parameters from the samba-style vscan configuration 
 * file
 *
 * Copyright (C) Rainer Link, 2004
 *		 OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * This module is used to parse commonly-used parameters (i.e. which
 * are the same for most vscan-samba VFS module) from the corresponding
 * vscan-samba configuration file.
 *
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/

#include "vscan-global.h"

/**
 * set default values for common parameters
 *
 * @param vscan_config	structure containing common parameters
 *
*/


void set_common_default_settings(vscan_config_struct *vscan_config)
{
	DEBUG(3, ("set_common_default_settings\n"));

        /* set default value for max file size */
        vscan_config->common.max_size = VSCAN_MAX_SIZE;
	DEBUG(3, ("default max size: %d\n", vscan_config->common.max_size));

        /* set default value for file logging */
        vscan_config->common.verbose_file_logging = VSCAN_VERBOSE_FILE_LOGGING;
	DEBUG(3, ("default verbose logging: %d\n", vscan_config->common.verbose_file_logging));

        /* set default value for scan on open() */
        vscan_config->common.scan_on_open = VSCAN_SCAN_ON_OPEN;
	DEBUG(3, ("default scan on open: %d\n", vscan_config->common.scan_on_open));

        /* set default value for scan on close() */
        vscan_config->common.scan_on_close = VSCAN_SCAN_ON_CLOSE;
	DEBUG(3, ("default value for scan on close: %d\n", vscan_config->common.scan_on_close));

        /* set default value for deny access on error */
        vscan_config->common.deny_access_on_error = VSCAN_DENY_ACCESS_ON_ERROR;
	DEBUG(3, ("default value for deny access on error: %d\n", vscan_config->common.deny_access_on_error));

        /* set default value for deny access on minor error */
        vscan_config->common.deny_access_on_minor_error = VSCAN_DENY_ACCESS_ON_MINOR_ERROR;
	DEBUG(3, ("default value for deny access on minor error: %d\n", vscan_config->common.deny_access_on_minor_error)); 

        /* set default value for send warning message */
        vscan_config->common.send_warning_message = VSCAN_SEND_WARNING_MESSAGE;
	DEBUG(3, ("default value send warning message: %d\n", vscan_config->common.send_warning_message));

        /* set default value for infected file action */
        vscan_config->common.infected_file_action = VSCAN_INFECTED_FILE_ACTION;
	DEBUG(3, ("default value infected file action: %d\n", vscan_config->common.infected_file_action));

        /* set default value for quarantine directory */
        fstrcpy(vscan_config->common.quarantine_dir, VSCAN_QUARANTINE_DIRECTORY);
	DEBUG(3, ("default value quarantine directory: %s\n", vscan_config->common.quarantine_dir));

        /* set default value for quarantine prefix */
        fstrcpy(vscan_config->common.quarantine_prefix, VSCAN_QUARANTINE_PREFIX);
	DEBUG(3, ("default value for quarantine prefix: %s\n", vscan_config->common.quarantine_prefix));

        /* set default value for maximum lrufile entries */
        vscan_config->common.max_lrufiles = VSCAN_MAX_LRUFILES;
	DEBUG(3, ("default value for max lrufile entries: %d\n", vscan_config->common.max_lrufiles));

        /* time after an entry is considered as expired */
        vscan_config->common.lrufiles_invalidate_time = VSCAN_LRUFILES_INVALIDATE_TIME;
	DEBUG(3, ("default value for invalidate time: %d\n", vscan_config->common.lrufiles_invalidate_time));

        /* file type exclude ist */
        pstrcpy(vscan_config->common.exclude_file_types, VSCAN_FT_EXCLUDE_LIST);
	DEBUG(3, ("default value for file type exclude: %s\n", vscan_config->common.exclude_file_types));

	/* file regexp exclude regexp */
	pstrcpy(vscan_config->common.exclude_file_regexp, VSCAN_FT_EXCLUDE_REGEXP);
	DEBUG(3, ("default value for file regexep exclude: %s\n", vscan_config->common.exclude_file_regexp));

}

/** 
 * get name of configuration file
 *
 * @param conn		pointer to connection
 * @param module_name	name of samba-vscan module
 * @param paramconf	name of default configuration file
 * @return The correct configuration file
 *
*/
/* FIXME: should we use const here? Should we use **conn instead? */

#if (SMB_VFS_INTERFACE_VERSION >= 6)
const char* get_configuration_file(const connection_struct *conn, fstring module_name, fstring paramconf)
#else
const char* get_configuration_file(const struct connection_struct *conn, fstring module_name, fstring paramconf)
#endif
{
	static fstring config_file;

        #if (SAMBA_VERSION_MAJOR==2 && SAMBA_VERSION_RELEASE>=4) || SAMBA_VERSION_MAJOR==3
         #if !(SMB_VFS_INTERFACE_VERSION >= 6)
          pstring opts_str;
          PROTOTYPE_CONST char *p;
         #endif
        #endif

         #if (SMB_VFS_INTERFACE_VERSION >= 6)
          fstrcpy(config_file, lp_parm_const_string(SNUM(conn),module_name,"config-file",paramconf));
         #else
          pstrcpy(opts_str, (const char*) lp_vfs_options(SNUM(conn)));
          if( !*opts_str ) {
                DEBUG(3, ("samba-vscan: no configuration file set - using default value (%s).\n", lp_vfs_options(SNUM(conn))));
          } else {
                p = opts_str;
                if ( next_token(&p, config_file, "=", sizeof(config_file)) ) {
                        trim_string(config_file, " ", " ");
                        if ( !strequal("config-file", config_file) ) {
                                DEBUG(3, ("samba-vscan - connect: options %s is not config-file\n", config_file));
                                /* setting default value */
                                fstrcpy(config_file, paramconf);

                        } else {
                                if ( !next_token(&p, config_file," \n",sizeof(config_file)) ) {
                                        DEBUG(3, ("samba-vscan - connect: no option after config-file=\n"));
                                        /* setting default value */
                                        fstrcpy(config_file, paramconf);
                                } else {
                                        trim_string(config_file, " ", " ");
                                        DEBUG(3, ("samba-vscan - connect: config file name is %s\n", config_file));
                                }
                        }
                }
          }
        #endif /*  #if (SMB_VFS_INTERFACE_VERSION >= 6)*/
	return config_file;
}



/**
 * parsing common parameters and values from config file
 *
 * @param vscan_config	containing common parameters
 * @param param		the parameter
 * @param value		the value
 *
*/

BOOL do_common_parameter(vscan_config_struct *vscan_config, const char *param, const char *value)
{
	/* we assume we handled a common parameter */
	BOOL ret = True;

        if ( StrCaseCmp("max file size", param) == 0 ) {
                /* FIXME: sanity check missing! what, if value is out of range?
                   atoi returns int - what about LFS? atoi should be avoided!
                */
		/* FIXME: changed atoi to atoll, but atoll might not be available
		   on all platforms! */
                vscan_config->common.max_size = atoll(value);
                DEBUG(3, ("max file size is: %lld\n", (long long)vscan_config->common.max_size));
        } else if ( StrCaseCmp("verbose file logging", param) == 0 ) {
                set_boolean(&vscan_config->common.verbose_file_logging, value);
                DEBUG(3, ("verbose file logging is: %d\n", vscan_config->common.verbose_file_logging));
        } else if ( StrCaseCmp("scan on open", param) == 0 ) {
                set_boolean(&vscan_config->common.scan_on_open, value);
                DEBUG(3, ("scan on open: %d\n", vscan_config->common.scan_on_open));
        } else if ( StrCaseCmp("scan on close", param) == 0 ) {
                set_boolean(&vscan_config->common.scan_on_close, value);
                DEBUG(3, ("scan on close is: %d\n", vscan_config->common.scan_on_close));
        } else if ( StrCaseCmp("deny access on error", param) == 0 ) {
                set_boolean(&vscan_config->common.deny_access_on_error, value);
                DEBUG(3, ("deny access on error is: %d\n", vscan_config->common.deny_access_on_error));
        } else if ( StrCaseCmp("deny access on minor error", param) == 0 ) {
                set_boolean(&vscan_config->common.deny_access_on_minor_error, value);
                DEBUG(3, ("deny access on minor error is: %d\n", vscan_config->common.deny_access_on_minor_error));
        } else if ( StrCaseCmp("send warning message", param) == 0 ) {
                set_boolean(&vscan_config->common.send_warning_message, value);
                DEBUG(3, ("send warning message is: %d\n", vscan_config->common.send_warning_message));
        } else if ( StrCaseCmp("infected file action", param) == 0 ) {
                if (StrCaseCmp("quarantine", value) == 0) {
                        vscan_config->common.infected_file_action = INFECTED_QUARANTINE;
                } else if (StrCaseCmp("delete", value) == 0) {
                        vscan_config->common.infected_file_action = INFECTED_DELETE;
                } else if (StrCaseCmp("nothing", value) == 0) {
                        vscan_config->common.infected_file_action = INFECTED_DO_NOTHING;
                } else {
                        DEBUG(2, ("samba-vscan: badly formed infected file action in configuration file, parameter %s\n", value));
                }
                DEBUG(3, ("infected file action is: %d\n", vscan_config->common.infected_file_action));
        } else if ( StrCaseCmp("quarantine directory", param) == 0 ) {
                fstrcpy(vscan_config->common.quarantine_dir, value);
                DEBUG(3, ("quarantine directory is: %s\n", vscan_config->common.quarantine_dir));
        } else if ( StrCaseCmp("quarantine prefix", param) == 0 ) {
                fstrcpy(vscan_config->common.quarantine_prefix, value);
                DEBUG(3, ("quarantine prefix is: %s\n", vscan_config->common.quarantine_prefix));
        } else if ( StrCaseCmp("max lru files entries", param) == 0 ) {
                vscan_config->common.max_lrufiles = atoi(value);
                DEBUG(3, ("max lru files entries is: %d\n", vscan_config->common.max_lrufiles));
        } else if ( StrCaseCmp("lru file entry lifetime", param) == 0 ) {
                vscan_config->common.lrufiles_invalidate_time = atol(value);
                DEBUG(3, ("lru file entry lifetime is: %li\n", (long)vscan_config->common.lrufiles_invalidate_time));
        } else if ( StrCaseCmp("exclude file types", param) == 0 ) {
                pstrcpy(vscan_config->common.exclude_file_types, value);
                DEBUG(3, ("exclude file type list is: %s\n", vscan_config->common.exclude_file_types));
	} else if ( StrCaseCmp("exclude file regexp", param) == 0 ) {
		pstrcpy(vscan_config->common.exclude_file_regexp, value);
		DEBUG(3, ("exclude file regexp is: %s\n", vscan_config->common.exclude_file_regexp));
	} else {
		/* unknown common parameter, it must be handled by 
		   corresponding module */
		DEBUG(5, ("unkown common parameter: %s\n", param));
		ret = False;
	}

	return ret;

}


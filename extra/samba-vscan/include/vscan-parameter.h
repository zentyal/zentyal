#ifndef __VSCAN_PARAMETER_H_
#define __VSCAN_PARAMETER_H_

/* begin configuration section */

/* False = log only infected file, True = log every file access */

#ifndef VSCAN_VERBOSE_FILE_LOGGING
# define VSCAN_VERBOSE_FILE_LOGGING False   
#endif

/* if a file is bigger than VSCAN_MAX_SIZE it won't be scanned. Has to be
   specified in bytes! If it set to 0, the file size check is disabled */

#ifndef VSCAN_MAX_SIZE 
# define VSCAN_MAX_SIZE 0 
#endif


/* True = scan files on open */

#ifndef VSCAN_SCAN_ON_OPEN 
# define VSCAN_SCAN_ON_OPEN True 
#endif

/* True = scan files on close */

#ifndef VSCAN_SCAN_ON_CLOSE
# define VSCAN_SCAN_ON_CLOSE True 
#endif


/* True = deny access in case of virus scanning failure */

#ifndef VSCAN_DENY_ACCESS_ON_ERROR
# define VSCAN_DENY_ACCESS_ON_ERROR True
#endif 

/* True = deny access in case of minor virus scanning failure */

#ifndef VSCAN_DENY_ACCESS_ON_MINOR_ERROR
# define VSCAN_DENY_ACCESS_ON_MINOR_ERROR True
#endif

/* True = send a warning message via window messenger service for viruses found */

#ifndef VSCAN_SEND_WARNING_MESSAGE
# define VSCAN_SEND_WARNING_MESSAGE True
#endif

/* default infected file action */
#define VSCAN_INFECTED_FILE_ACTION INFECTED_QUARANTINE

/* default quarantine settings; hopefully the user changes this */
#define VSCAN_QUARANTINE_DIRECTORY "/tmp"
#define VSCAN_QUARANTINE_PREFIX    "vir-"

/* set default value for maximum lrufile entries */
#define VSCAN_MAX_LRUFILES 100

/* time after an entry is considered as expired */
#define VSCAN_LRUFILES_INVALIDATE_TIME 5

/* MIME-types of files to be exluded from scanning; that's an
   semi-colon seperated list */
#define VSCAN_FT_EXCLUDE_LIST ""

#define VSCAN_FT_EXCLUDE_REGEXP ""

/* end configuration section. Do not change anything below
   unless you know what you're doing :)
*/

typedef struct {
	struct {
                ssize_t max_size;               /* do not scan files greater than max_size
                                                if max_size = 0, scan any file */
                BOOL verbose_file_logging;      /* log every file access */
                BOOL scan_on_open;              /* scan a file before it is opened
                                                   Defaults to True
                                                */
                BOOL scan_on_close;             /* scan a new file put on share or
                                                   if file was modified
                                                   Defaults to False
                                                */
                BOOL deny_access_on_error;      /* if connection to daemon fails,  should access to any
                                                   file be denied? Defaults to True
                                                */

                BOOL deny_access_on_minor_error; /* if daemon returns non-critical error,
                                                    should access to the file be denied? */
                BOOL send_warning_message;      /* send a warning message using the windows
                                                   messenger service? */
                fstring quarantine_dir;         /* directory for infected files */
                fstring quarantine_prefix;      /* prefix    for infected files */
                enum infected_file_action_enum infected_file_action; /* what to do with infected files;
                                                                        defaults to quarantine */
                int max_lrufiles;               /* specified the maximum entries in lrufiles list */
                time_t lrufiles_invalidate_time; /* specified the time in seconds after the lifetime
                                                    of an entry is expired and entry will be invalidated */
                pstring exclude_file_types;     /* list of file types which should be excluded from scanning */
                pstring exclude_file_regexp;     /* regexp which should be excluded from scanning */
        } common;
	void* specific;
} vscan_config_struct;

BOOL do_common_parameter(vscan_config_struct *vscan_config, const char *param, const char *value);
void set_common_default_settings(vscan_config_struct *vscan_config);
#if (SMB_VFS_INTERFACE_VERSION >= 6)
const char* get_configuration_file(const connection_struct *conn, fstring module_name, fstring paramconf);
#else
const char* get_configuration_file(const struct connection_struct *conn, fstring module_name, fstring paramconf);
#endif


#endif /* __VSCAN_PARAMETER_H_ */

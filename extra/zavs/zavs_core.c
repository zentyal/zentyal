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
#include "zavs_clamav.h"

// This struct store the module configuration
static zavs_config_struct zavs_config;

void zavs_initialize(vfs_handle_struct *handle, const char *service, const char *user, const char *address)
{
    ZAVS_INFO("Zentyal AntiVirus for Samba (%s) connected (%s), (c) by eBox Technologies", MODULE_VERSION, SAMBA_VERSION);
    ZAVS_INFO("Connect to service '%s' by user '%s' from '%s'", service, user, address);

    // Parse user specified settings
    zavs_parse_settings(handle, &zavs_config);

    // Initialise clamav library
    ZAVS_DEBUG(5, "init clamav library\n");
	zavs_clamav_lib_init(&zavs_config);

    // Initialise lrufiles list
    ZAVS_DEBUG(5, "init lrufiles list\n");
    lrufiles_init(zavs_config.common.max_lrufiles, zavs_config.common.lrufiles_invalidate_time);

    // Initialise file type exclussion
    ZAVS_DEBUG(5, "init file type\n");
    filetype_init(0, zavs_config.common.exclude_file_types);

    // Initialise file regexp exclussion
    ZAVS_DEBUG(5, "init file regexp\n");
    fileregexp_init(zavs_config.common.exclude_file_regexp);
}

void zavs_finalize(void)
{
    ZAVS_INFO("disconnected");
    fileregexp_close();
    filetype_close();
    lrufiles_destroy_all();
	zavs_clamav_lib_done();
}

bool zavs_open_handler(vfs_handle_struct *handle, files_struct *fsp)
{
    bool allow_access = true;
    char filepath[1024];

    // Build the full file path
    memset(filepath, 0, sizeof(filepath));
    snprintf(filepath, sizeof(filepath)-1, "%s/%s", fsp->conn->connectpath, fsp->fsp_name->base_name);

    if (!zavs_config.common.scan_on_open) {
        // Scan files on open not set
        ZAVS_DEBUG(3, "File '%s' not scanned as 'scan on open' is not set\n", filepath);
    } else if (!skip_file(handle, fsp, filepath)) {
//        char client_ip[CLIENT_IP_SIZE];
//        int must_be_checked;
//
//        safe_strcpy(client_ip, handle->conn->client_address, CLIENT_IP_SIZE - 1);
//
//        // must file actually be scanned?
//        must_be_checked = lrufiles_must_be_checked(filepath, stat_buf.st_mtime);
//
//        if (must_be_checked == ZAVS_LRU_DENY_ACCESS) {
//            // File has already been checked and marked as infected
//            if ( vscan_config.common.verbose_file_logging )
//                vscan_syslog("INFO: File '%s' has already been scanned and marked as infected. Not scanned any more. Access denied", filepath);
//            errno = EACCES;
//            return -1;
//        } else if (must_be_checked == ZAVS_LRU_GRANT_ACCESS) {
//            // File has already been checked, not marked as infected and not modified
//            if (vscan_config.common.verbose_file_logging)
//                vscan_syslog("INFO: File '%s' has already been scanned, not marked as infected and not modified. Not scanned anymore. Access granted", filepath);
//        } else {
            // Scan the file
            int retval = zavs_clamav_lib_scanfile(filepath, &zavs_config);
            if (retval == ZAVS_SCAN_CLEAN) {
                allow_access = true;
            } else if (retval == ZAVS_SCAN_INFECTED) {
                errno = EACCES;
                allow_access = false;
            } else if (retval == ZAVS_SCAN_ERROR) {
                if (zavs_config.common.deny_access_on_error) {
                    ZAVS_INFO("Access to file '%s' denied as 'deny access on error' is set", filepath);
                    errno = EACCES;
                    allow_access = false;
                } else {
                    allow_access = true;
                }
            }
        }
    return allow_access;
}

void zavs_close_handler(vfs_handle_struct *handle, files_struct *fsp)
{
    char filepath[1024];

    // Build the full file path
    memset(filepath, 0, sizeof(filepath));
    snprintf(filepath, sizeof(filepath)-1, "%s/%s", fsp->conn->connectpath, fsp->fsp_name->base_name);

    if (!zavs_config.common.scan_on_close) {
        // Scan files on close not set
        ZAVS_DEBUG(3, "File '%s' not scanned as 'scan on close' is not set\n", filepath);
    } else if (!fsp->modified) {
        // Don't scan files which have not been modified
        if (zavs_config.common.verbose_file_logging)
            ZAVS_INFO("File '%s' was not modified - not scanned", filepath);
    } else if (!skip_file(handle, fsp, filepath)) {
        zavs_clamav_lib_scanfile(filepath, &zavs_config);
    }
}

bool skip_file(vfs_handle_struct *handle, files_struct *fsp, const char *filepath)
{
    bool ret = false;
    struct stat statbuf;

    if ((ret = stat(filepath, &statbuf)) != 0) {
        // An error occured
        ret = true;
        if (errno == ENOENT) {
            if (zavs_config.common.verbose_file_logging)
                ZAVS_WARN("File '%s' not found! Not scanned!", filepath);
        } else {
            ZAVS_ERROR("File '%s' not readable or an error occured", filepath);
        }
    } else if (S_ISDIR(statbuf.st_mode)) {
        // It a directory
        ret = true;
        if (zavs_config.common.verbose_file_logging)
            ZAVS_INFO("open: File '%s' is a directory! Not scanned!", filepath);
    } else if (statbuf.st_size == 0) {
        // Do not scan empty files
        ret = true;
        if (zavs_config.common.verbose_file_logging)
            ZAVS_INFO("open: File '%s' has size zero! Not scanned!", filepath);
    } else if (fileregexp_skipscan(filepath) == ZAVS_FR_SKIP_SCAN) {
        // Check regular expression exlude
        ret = true;
        if (zavs_config.common.verbose_file_logging)
            ZAVS_INFO("open: File '%s' not scanned as file is machted by exclude regexp", filepath);
    } else if (filetype_skipscan(filepath) == ZAVS_FT_SKIP_SCAN) {
        // Check file type exclude
        ret = true;
        if (zavs_config.common.verbose_file_logging)
            ZAVS_INFO("open: File '%s' not scanned as file type is on exclude list", filepath);
    }
    return ret;
}

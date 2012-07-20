#include <clamav.h>
#include <stdbool.h>

#include "zavs_clamav.h"
#include "zavs_log.h"

static struct cl_engine *engine;
static bool clamav_loaded;

void zavs_clamav_lib_init(const zavs_config_struct *config)
{
    unsigned int sigs = 0;
    int ret;

    // Initialize library
    if ((ret = cl_init(CL_INIT_DEFAULT)) != CL_SUCCESS) {
        ZAVS_ERROR("Could not initialize libclamav: %s\n", cl_strerror(ret));
        clamav_loaded = false;
        return;
    }

    // Load scan engine
    if (!(engine = cl_engine_new())) {
        ZAVS_ERROR("Could not create clamav engine\n");
        clamav_loaded = false;
        return;
    }

    // Set the engine limits
    zavs_set_engine_option(CL_ENGINE_MAX_SCANSIZE, config->clamav_limits.max_scan_size);
    zavs_set_engine_option(CL_ENGINE_MAX_FILESIZE, config->clamav_limits.max_file_size);
    zavs_set_engine_option(CL_ENGINE_MAX_RECURSION, config->clamav_limits.max_recursion_level);
    zavs_set_engine_option(CL_ENGINE_MAX_FILES, config->clamav_limits.max_files);

    // Load all available databases from default directory
    if ((ret = cl_load(cl_retdbdir(), engine, &sigs, CL_DB_STDOPT)) != CL_SUCCESS) {
        ZAVS_ERROR("Could not load clamav database: %s\n", cl_strerror(ret));
        cl_engine_free(engine);
        clamav_loaded = false;
        return;
    }

    // Build engine
    if ((ret = cl_engine_compile(engine)) != CL_SUCCESS) {
        ZAVS_ERROR("Database initialization error: %s\n", cl_strerror(ret));
        cl_engine_free(engine);
        clamav_loaded = false;
        return;
    }

    ZAVS_INFO("ClamAV engine initialized, %u signatures loaded\n", sigs);
    clamav_loaded = true;
}

void zavs_clamav_lib_done()
{
    cl_engine_free(engine);
    clamav_loaded = false;
}

/**
  *
  * Scan a file descriptor using lib clamav
  *
  */
int zavs_clamav_lib_scanfile(const char *filepath, const zavs_config_struct *config)
{
    const char *virname;
    int ret;

    ret = cl_scanfile(filepath, &virname, NULL, engine, CL_SCAN_STDOPT);
    if (ret == CL_CLEAN) {
        // No virus found
        if (config->common.verbose_file_logging)
            ZAVS_INFO("Access to file '%s' granted, no virus detected\n", filepath);

        // File is clean, add to lrufiles
        // TODO lrufiles_add(filepath, stat_buf.st_mtime, false);

        ret = ZAVS_SCAN_CLEAN;
    } else if (ret == CL_VIRUS) {
        // Virus found
        ZAVS_WARN("VIRUS DETECTED! virus '%s' detected in file '%s'\n", virname, filepath);
        // TODO zavs_log_virus(filepath, virname, client_ip);

        // Do action
        // TODO zavs_do_infected_file_action(handle, handle->conn, filepath, config);

        // Add/update file. mark file as infected!
        // TODO lrufiles_add(filepath, stat_buf.st_mtime, true);

        ret = ZAVS_SCAN_INFECTED;
    } else {
        ZAVS_ERROR("ClamAV library returned an error scaning file '%s': %s", filepath, cl_strerror(ret));

        // To be safe, remove file from lrufiles
        // TODO lrufiles_delete(filepath);

        ret = ZAVS_SCAN_ERROR;
    }
    return ret;
}

void zavs_set_engine_option(enum cl_engine_field field, long long value)
{
    int ret;

    if ((ret = cl_engine_set_num(engine, field, value)) != CL_SUCCESS) {
        ZAVS_ERROR("Could not set clamav engine options: %s\n", cl_strerror(ret));
    }
}


/*
 * Upgrade a mailbox from Exchange to Openchange
 *
 * OpenChange Project
 *
 * Copyright (C) Zentyal SL 2013
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "migrate.h"

enum
{
    OPT_DEBUG = 1000,
    OPT_DUMPDATA
};

static struct poptOption long_options[] =
{
    POPT_AUTOHELP
    { "debuglevel", 'd', POPT_ARG_STRING, NULL, OPT_DEBUG,
        "set the debug level", NULL },
    {"dump-data", 0, POPT_ARG_NONE, NULL, OPT_DUMPDATA,
        "dump the hexadecimal and NDR data", NULL },
    {NULL, 0, 0, NULL, 0, NULL, NULL},
};

void set_debug_level(TALLOC_CTX *mem_ctx, struct status *status, char *opt)
{
    char *opttmp = NULL;
    char *endptr = NULL;
    char *debuglevel;
    int val = 0;
    struct loadparm_context *lp_ctx;

    opttmp = talloc_strdup(mem_ctx, opt);
    val = strtol(opttmp, &endptr, 10);
    if ((errno == ERANGE && (val == LONG_MAX || val == LONG_MIN)) ||
        (errno != 0 && val == 0))
    {
        fprintf(stderr, "[!] Error parsing debug option\n");
    }
    if (endptr == opttmp) {
        fprintf(stderr, "[!] Error parsing debug option\n");
    }
    talloc_free(opttmp);

    lp_ctx = loadparm_init_global(true);
    debuglevel = talloc_asprintf(mem_ctx, "%u", val);
    lpcfg_set_cmdline(lp_ctx, "log level", debuglevel);
    talloc_free(debuglevel);

    status->local.debug_level = val;
    status->remote.debug_level = val;
}

int main(int argc, const char *argv[])
{
    TALLOC_CTX      *mem_ctx = NULL;
    struct status   *status  = NULL;
    struct pidfh    *pfh = NULL;;
    int             opt = 0;
    int         ret = 0;
    poptContext     pc;
    pid_t           pid;

    /* Initialize status structure */
    mem_ctx = talloc_named(NULL, 0, "migrate");
    if (mem_ctx == NULL) {
        fprintf(stderr, "[!] Not enough memory\n");
        exit(EXIT_FAILURE);
    }
    status = talloc_zero(mem_ctx, struct status);
    if (!status) {
        goto fail;
    }
    status->state = STATE_IDLE;
    status->mem_ctx = mem_ctx;

    ret = pthread_spin_init(&status->lock, PTHREAD_PROCESS_PRIVATE);
    if (ret) {
        fprintf(stderr, "[!] pthread_spin_init: %s\n", strerror(ret));
        goto fail;
    }

    /* Parse command line options */
    pc = poptGetContext("migrate", argc, argv, long_options, 0);
    while ((opt = poptGetNextOpt(pc)) != -1) {
        switch (opt) {
            case OPT_DUMPDATA:
                status->local.dumpdata = true;
                status->remote.dumpdata = true;
                break;
            case OPT_DEBUG:
                set_debug_level(status->mem_ctx,
                    status, poptGetOptArg(pc));
                break;
            default:
                fprintf(stderr, "[!] Non-existent option\n");
                goto fail;
        }
    }

    /* Sanity check on options */
    if (!status->opt_profdb) {
        status->opt_profdb = talloc_asprintf(mem_ctx,
                DEFAULT_PROFDB, getenv("HOME"));
    }

    /* Open PID file, exit if file locked (already running) */
    pfh = pidfile_open(NULL, 0600, &pid);
    if (pfh == NULL) {
        if (errno == EEXIST) {
            fprintf(stderr,
                "[!] Daemon already running, pid: %jd\n",
                (intmax_t)pid);
        } else {
            fprintf(stderr,
                "[!] Cannot open or create pidfile: %s\n",
                strerror(errno));
        }
        goto fail;
    }

    /* Daemonize if no debug */
    if (!status->local.debug_level && !status->remote.debug_level) {
        if (daemon(0, 0) == -1) {
            fprintf(stderr, "[!] Cannot daemonize: %s\n",
                strerror(errno));
            goto fail;
        }
    }

    /* This is child code. Write PID on file */
    pidfile_write(pfh);

    /* Init RPC communications */
    if (!rpc_open(status)) {
        goto fail;
    }

    /* Init the control loop */
    status->rpc_run = true;
    rpc_run(status);

    /* Cleanup */
    rpc_close(status);

    ret = pthread_spin_destroy(&status->lock);
    if (ret) {
        fprintf(stderr, "[!] pthread_spin_destroy: %s\n", strerror(ret));
    }
    talloc_free(status);
    talloc_free(mem_ctx);
    poptFreeContext(pc);

    /* Close and remove PID file */
    pidfile_remove(pfh);

    exit(EXIT_SUCCESS);
fail:
    if (status) {
        rpc_close(status);
        talloc_free(status);
    }
    if (mem_ctx) {
        talloc_free(mem_ctx);
    }
    if (pc) {
        poptFreeContext(pc);
    }
    if (pfh) {
        pidfile_remove(pfh);
    }
    exit(EXIT_FAILURE);
}

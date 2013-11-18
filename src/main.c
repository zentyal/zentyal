/*
 * Migrate a profile mailbox from Exchange to Openchange
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

#include <inttypes.h>
#include <popt.h>
#include <stdlib.h>
#include <limits.h>
#include <bsd/libutil.h>

#include "migrate.h"
#include "rpc.h"

#define DEFAULT_PROFDB          "%s/.openchange/profiles.ldb"

int main(int argc, const char *argv[])
{
    TALLOC_CTX      *mem_ctx = NULL;
    struct status   *status  = NULL;
    poptContext     pc;
    int             opt;
    struct pidfh    *pfh;
    pid_t           pid;

    enum { OPT_DEBUG=1000, OPT_DUMPDATA };
    struct poptOption long_options[] = {
        POPT_AUTOHELP
        {"debuglevel", 'd', POPT_ARG_STRING, NULL, OPT_DEBUG, "set the debug level", NULL },
        {"dump-data", 0, POPT_ARG_NONE, NULL, OPT_DUMPDATA, "dump the hexadecimal and NDR data", NULL },
        {NULL, 0, 0, NULL, 0, NULL, NULL}
    };

    /* Initialize status structure */
    mem_ctx = talloc_named(NULL, 0, "mailboxsize");
    if (mem_ctx == NULL) {
        DEBUG(0, ("[!] Not enough memory\n"));
        exit(EXIT_FAILURE);
    }
    status = talloc_zero(mem_ctx, struct status);
    if (!status) {
        goto fail;
    }
    status->state = STATE_IDLE;
    status->mem_ctx = mem_ctx;

    /* Parse command line options */
    pc = poptGetContext("mailboxsize", argc, argv, long_options, 0);
    while ((opt = poptGetNextOpt(pc)) != -1) {
        switch (opt) {
        case OPT_DUMPDATA:
            status->opt_dumpdata = true;
            break;
        case OPT_DEBUG:
            {
                char *opt_tmp, *endptr;
                int val;
                opt_tmp = poptGetOptArg(pc);
                val = strtol(opt_tmp, &endptr, 10);
                if ((errno == ERANGE && (val == LONG_MAX || val == LONG_MIN)) || (errno != 0 && val == 0)) {
                    DEBUG(0, ("[!] Error parsing debug option\n"));
                    goto fail;
                }
                if (endptr == opt_tmp) {
                    DEBUG(0, ("[!] Error parsing debug option\n"));
                    goto fail;
                }
                status->opt_debug = val;
                free(opt_tmp);
                break;
            }
        default:
            DEBUG(0, ("[!] Non-existent option\n"));
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
            DEBUG(0, ("[!] Daemon already running, pid: %jd.", (intmax_t)pid));
        } else {
            DEBUG(0, ("[!] Cannot open or create pidfile: %s\n", strerror(errno)));
        }
        goto fail;
    }

    /* Daemonize if no debug */
    if (status->opt_debug == 0) {
        if (daemon(0, 0) == -1) {
            DEBUG(0, ("[!] Cannot daemonize: %s\n", strerror(errno)));
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

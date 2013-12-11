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

#ifndef __MIGRATE_H__
#define __MIGRATE_H__

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <limits.h>
#include <time.h>
#include <pthread.h>

#include <amqp.h>
#include <amqp_tcp_socket.h>
#include <amqp_framing.h>

#include <popt.h>
#include <bsd/libutil.h>

#include <json/json.h>
#include <json/arraylist.h>

#include <libmapi/libmapi.h>
#include <libocpf/ocpf.h>

#define DEFAULT_PROFDB      "%s/.openchange/profiles.ldb"
#define DEFAULT_EXPORT_PATH     "/var/tmp/openchange-migrate"
#define TDB_SYSFOLDER       "systemfolder.tdb"
#define TDB_FOLDERMAP       "foldermap.tdb"


#ifndef __BEGIN_DECLS
#ifdef __cplusplus
#define __BEGIN_DECLS       extern "C" {
#define __END_DECLS     }
#else
#define __BEGIN_DECLS
#define __END_DECLS
#endif
#endif

struct mbox_tree_item {
    struct mbox_tree_item   *parent;
    struct mbox_tree_item   *children;
    struct mbox_tree_item   *next;
    struct mbox_tree_item   *prev;
    mapi_id_t       id;
};

struct mbox_counters {
    uint64_t        total_folders;
    uint64_t        exported_total_folders;
    uint64_t        imported_total_folders;

    uint64_t        total_items;
    uint64_t        exported_total_items;
    uint64_t        imported_total_items;

    uint64_t        total_bytes;
    uint64_t        exported_total_bytes;
    uint64_t        imported_total_bytes;

    uint64_t        email_items;
    uint64_t        exported_email_items;
    uint64_t        imported_email_items;

    uint64_t        email_bytes;
    uint64_t        exported_email_bytes;
    uint64_t        imported_email_bytes;

    uint64_t        attachment_items;
    uint64_t        exported_attachment_items;
    uint64_t        imported_attachment_items;

    uint64_t        attachment_bytes;
    uint64_t        exported_attachment_bytes;
    uint64_t        imported_attachment_bytes;

    uint64_t        note_items;
    uint64_t        exported_note_items;
    uint64_t        imported_note_items;

    uint64_t        note_bytes;
    uint64_t        exported_note_bytes;
    uint64_t        imported_note_bytes;

    uint64_t        appointment_items;
    uint64_t        exported_appointment_items;
    uint64_t        imported_appointment_items;

    uint64_t        appointment_bytes;
    uint64_t        exported_appointment_bytes;
    uint64_t        imported_appointment_bytes;

    uint64_t        task_items;
    uint64_t        exported_task_items;
    uint64_t        imported_task_items;

    uint64_t        task_bytes;
    uint64_t        imported_task_bytes;
    uint64_t        exported_task_bytes;

    uint64_t        contact_items;
    uint64_t        imported_contact_items;
    uint64_t        exported_contact_items;

    uint64_t        contact_bytes;
    uint64_t        imported_contact_bytes;
    uint64_t        exported_contact_bytes;

    uint64_t        journal_items;
    uint64_t        imported_journal_items;
    uint64_t        exported_journal_items;

    uint64_t        journal_bytes;
    uint64_t        imported_journal_bytes;
    uint64_t        exported_journal_bytes;
};

struct mbox_data {
    const char      *username;
    time_t          start_time;
    time_t          end_time;
    struct mbox_counters    counters;
    struct mbox_tree_item   *tree_root;
    struct tdb_context  *tdb_sysfolder;
    struct tdb_context  *tdb_foldermap;
};

enum state {
    STATE_IDLE      = 0,
    STATE_ESTIMATING    = 1,
    STATE_ESTIMATED     = 2,
    STATE_EXPORTING     = 3,
    STATE_EXPORTED      = 4,
    STATE_IMPORTING     = 5,
    STATE_IMPORTED      = 6
};

struct connection
{
    struct mapi_context *mapi_ctx;
    struct mapi_session *session;
    char    *server;
    char    *error;
    bool    dumpdata;
    int debug_level;
};

struct status
{
    pthread_spinlock_t  lock;       /* Structure lock */
    enum state      state;      /* Internal state */
    TALLOC_CTX      *mem_ctx;   /* Application memory ctx */
    char            *opt_profdb;    /* Profile DB */
    amqp_connection_state_t conn;       /* AMQP connection */
    bool            rpc_run;    /* RPC run loop flag */
    struct json_tokener *tokener;   /* JSON parser */
    pthread_t       thread_id;  /* Worker thread id */
    time_t          start_time;
    time_t          end_time;
    struct array_list   *mbox_list;
    struct connection   remote;     /* Remote server connection */
    struct connection   local;      /* Local server connection */
};

__BEGIN_DECLS

/* definitions from estimate.c */
void        estimate_data_free(void *);
void        *estimate_start_thread(void *);
void        *export_start_thread(void *);
void        *import_start_thread(void *);
void        import_mailbox(TALLOC_CTX *mem_ctx, struct mapi_session *session, struct mbox_data *mdata);

/* definitions from rpc.c */
bool        rpc_open(struct status *);
void        rpc_close(struct status *);
void        rpc_run(struct status *);

/* definitions from control.c */
bool        control_init(struct status *);
void        control_free(struct status *);
void        control_abort(struct status *);
json_object *control_handle_status(struct status *, json_object *);
amqp_bytes_t    control_handle(struct status *, amqp_bytes_t);

__END_DECLS

#endif /* ! __MIGRATE_H__ */

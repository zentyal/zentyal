/*
   Recursively calculate the size of the mailbox

   OpenChange Project

   Copyright (C) Julien Kerihuel 2013

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/*
  gcc mailboxsize.c -o mailboxsize `pkg-config libmapi --cflags --libs` `pkg-config popt --cflags --libs`
 */

#include "libmapi/libmapi.h"
#include <inttypes.h>
#include <stdlib.h>
#include <popt.h>
#include <amqp_tcp_socket.h>
#include <amqp.h>
#include <amqp_framing.h>

struct mailboxitems {
    uint32_t    total;
    uint32_t    mail;
    uint32_t    attachments;
    uint32_t    attachmentSize;
    uint32_t    stickynote;
    uint32_t    appointment;
    uint32_t    task;
    uint32_t    contact;
    uint32_t    journal;
};

struct mailboxdata {
    int64_t         MailboxSize;
    uint32_t        FolderCount;
    struct mailboxitems items;
};

#define DEFAULT_PROFDB  "%s/.openchange/profiles.ldb"

extern struct poptOption popt_openchange_version[];
#define POPT_OPENCHANGE_VERSION { NULL, 0, POPT_ARG_INCLUDE_TABLE, popt_openchange_version, 0, "Common openchange options:", NULL },

static void popt_openchange_version_callback(poptContext con,
                         enum poptCallbackReason reason,
                         const struct poptOption *opt,
                         const char *arg,
                         const void *data)
{
    switch (opt->val) {
    case 'V':
        printf("Version %s\n", OPENCHANGE_VERSION_STRING);
        exit (0);
    }
}

struct poptOption popt_openchange_version[] = {
    { NULL, '\0', POPT_ARG_CALLBACK, (void *)popt_openchange_version_callback, '\0', NULL, NULL },
    { "version", 'V', POPT_ARG_NONE, NULL, 'V', "Print version ", NULL },
    POPT_TABLEEND
};

void handle_amqp_error(amqp_rpc_reply_t x, char const *context)
{

    switch (x.reply_type) {
        case AMQP_RESPONSE_NORMAL:
            return;
        case AMQP_RESPONSE_NONE:
            DEBUG(0, ("%s: missing RPC reply type!\n", context));
            break;
        case AMQP_RESPONSE_LIBRARY_EXCEPTION:
            DEBUG(0, ("%s: %s\n", context,
                      amqp_error_string2(x.library_error)));
            break;

        case AMQP_RESPONSE_SERVER_EXCEPTION:
            switch (x.reply.id) {
                case AMQP_CONNECTION_CLOSE_METHOD: {
                    amqp_connection_close_t *m = (
                        amqp_connection_close_t *) x.reply.decoded;
                    DEBUG(0, (
                        "%s: server connection error %d, message: %.*s\n",
                        context,
                        m->reply_code,
                        (int) m->reply_text.len,
                        (char *) m->reply_text.bytes));
                    break;
                }
                case AMQP_CHANNEL_CLOSE_METHOD: {
                    amqp_channel_close_t *m = (
                        amqp_channel_close_t *) x.reply.decoded;
                    DEBUG(0, (
                        "%s: server channel error %d, message: %.*s\n",
                        context,
                        m->reply_code,
                        (int) m->reply_text.len,
                        (char *) m->reply_text.bytes));
                        break;
                }
                default:
                    DEBUG(0, (
                        "%s: unknown server error, method id 0x%08X\n",
                        context, x.reply.id));
                    break;
            }
            break;
    }
    exit(1);
}

amqp_connection_state_t get_amqp_connection()
{
    amqp_connection_state_t conn;
    int status;
    amqp_socket_t *socket = NULL;

    conn = amqp_new_connection();
    socket = amqp_tcp_socket_new(conn);
    if (!socket) {
        DEBUG(0, ("[!] Error creating the TCP socket!\n"));
        exit(1);
    }

    status = amqp_socket_open(socket, "localhost", 5672);
    if (status) {
        DEBUG(0, ("[!] Error opening the TCP socket!\n"));
        exit(1);
    }

    handle_amqp_error(
        amqp_login(conn, "/", 0, 131072, 0, AMQP_SASL_METHOD_PLAIN,
                   "guest", "guest"),
        "Logging in");
    amqp_channel_open(conn, 1);
    handle_amqp_error(amqp_get_rpc_reply(conn), "Opening channel");

    return conn;

}

void close_amqp_connection(amqp_connection_state_t conn)
{
    handle_amqp_error(amqp_channel_close(conn, 1, AMQP_REPLY_SUCCESS),
                       "Closing channel");
    handle_amqp_error(amqp_connection_close(conn, AMQP_REPLY_SUCCESS),
                       "Closing connection");
    if (amqp_destroy_connection(conn) < 0) {
        DEBUG(0, ("[!] Error ending connection\n"));
        exit(1);
    }
}

char *mailboxdata_as_json(TALLOC_CTX *mem_ctx, struct mailboxdata *mdata)
{
    return talloc_asprintf(mem_ctx, "{\n" \
        "    \"MailboxSize\": \"%" PRId64 "\"," \
        "    \"FolderCount\": \"%d\"," \
        "    \"items\": {\n" \
        "        \"total\": \"%d\"," \
        "        \"mail\": \"%d\"," \
        "        \"attachments\": \"%d\"," \
        "        \"attachmentSize\": \"%d\"," \
        "        \"stickynote\": \"%d\"," \
        "        \"appointment\": \"%d\"," \
        "        \"task\": \"%d\"," \
        "        \"contact\": \"%d\"," \
        "        \"journal\": \"%d\"," \
        "    },\n" \
        "}\n", mdata->MailboxSize, mdata->FolderCount, mdata->items.total,
        mdata->items.mail, mdata->items.attachments,
        mdata->items.attachmentSize, mdata->items.stickynote,
        mdata->items.appointment, mdata->items.task, mdata->items.contact,
        mdata->items.journal);
}

static enum MAPISTATUS send_calculation(
    amqp_connection_state_t conn, struct mailboxdata *mdata,
    TALLOC_CTX *mem_ctx)
{
    amqp_basic_properties_t props;
    int result;
    char *messagebody;

    DEBUG(9, ("[+] Sending progress information\n"));
    props._flags = (
        AMQP_BASIC_CONTENT_TYPE_FLAG | AMQP_BASIC_DELIVERY_MODE_FLAG);
    props.content_type = amqp_cstring_bytes("text/plain");
    props.delivery_mode = 2; /* persistent delivery mode */

    messagebody = mailboxdata_as_json(mem_ctx, mdata);
    DEBUG(0, ("[+] DUMP:\n%s", messagebody));
    result = amqp_basic_publish(
        conn, 1, amqp_cstring_bytes("openchange_upgrade_calculation"),
        amqp_cstring_bytes(""), 0, 0, &props, amqp_cstring_bytes(messagebody));
    talloc_free(messagebody);
    if (result < 0) {
        DEBUG(0, ("[!] Error sending calculation update\n"));
        exit(1);
    }

    return MAPI_E_SUCCESS;
}

static enum MAPISTATUS folder_count_attachments(TALLOC_CTX *mem_ctx,
                        mapi_object_t *obj_store,
                        mapi_object_t *obj_folder,
                        struct mailboxdata *mdata,
                        amqp_connection_state_t conn)
{
    enum MAPISTATUS     retval = MAPI_E_SUCCESS;
    mapi_object_t       obj_ctable;
    mapi_object_t       obj_atable;
    mapi_object_t       obj_msg;
    struct SPropTagArray    *SPropTagArray;
    struct SRowSet      rowset;
    struct SRow     aRow;
    struct SRowSet      arowset;
    const uint8_t       *has_attach;
    uint64_t        *fid;
    uint64_t        *msgid;
    const char      *filename;
    uint32_t        *attachmentsize;
    uint32_t        index;
    uint32_t        aindex;

    mapi_object_init(&obj_ctable);

    retval = GetContentsTable(obj_folder, &obj_ctable, 0, NULL);
    MAPI_RETVAL_IF(retval, retval, NULL);

    SPropTagArray = set_SPropTagArray(mem_ctx, 0x3,
                      PidTagFolderId,
                      PidTagMid,
                      PidTagHasAttachments);
    retval = SetColumns(&obj_ctable, SPropTagArray);
    if (retval) {
        mapi_object_release(&obj_ctable);
        MAPIFreeBuffer(SPropTagArray);
        return retval;
    }
    MAPIFreeBuffer(SPropTagArray);

    while (((retval = QueryRows(&obj_ctable, 0x32, TBL_ADVANCE, &rowset)) != MAPI_E_NOT_FOUND)
           && rowset.cRows) {
        for (index = 0; index < rowset.cRows; index++) {
            aRow = rowset.aRow[index];
            fid = (uint64_t *) find_SPropValue_data(&aRow, PidTagFolderId);
            msgid = (uint64_t *) find_SPropValue_data(&aRow, PidTagMid);
            has_attach = (const uint8_t *) find_SPropValue_data(&aRow, PidTagHasAttachments);

            DEBUG(4, ("[+][attachments][mid=%"PRIx64"][attachments=%s]\n", *msgid, (*has_attach==true)?"yes":"no"));

            /* If we have attachments */
            if (has_attach && *has_attach == true) {
                mapi_object_init(&obj_msg);

                retval = OpenMessage(obj_store, *fid, *msgid, &obj_msg, 0);
                if (retval) continue;

                mapi_object_init(&obj_atable);
                retval = GetAttachmentTable(&obj_msg, &obj_atable);
                if (retval) {
                    mapi_object_release(&obj_msg);
                    continue;
                }
                SPropTagArray  = set_SPropTagArray(mem_ctx, 0x2,
                                   PidTagAttachLongFilename,
                                   PidTagAttachSize);
                retval = SetColumns(&obj_atable, SPropTagArray);
                MAPIFreeBuffer(SPropTagArray);
                if (retval) {
                    mapi_object_release(&obj_atable);
                    mapi_object_release(&obj_msg);
                    continue;
                }

                while (((retval = QueryRows(&obj_atable, 0x32, TBL_ADVANCE, &arowset)) != MAPI_E_NOT_FOUND) && arowset.cRows) {
                    for (aindex = 0; aindex < arowset.cRows; aindex++) {
                        attachmentsize = (uint32_t *) find_SPropValue_data(&arowset.aRow[aindex], PidTagAttachSize);
                        filename = (const char *) find_SPropValue_data(&arowset.aRow[aindex], PidTagAttachLongFilename);
                        mdata->items.attachmentSize += *attachmentsize;
                        mdata->items.attachments += 1;
                        send_calculation(conn, mdata, mem_ctx);

                        DEBUG(3, ("[+][attachment][mid=%"PRIx64"][filename=%s][size=%d]\n",
                              *msgid, filename, *attachmentsize));
                    }
                }

                mapi_object_release(&obj_atable);
                mapi_object_release(&obj_msg);
            }
        }
    }
    mapi_object_release(&obj_ctable);
    return MAPI_E_SUCCESS;
}


static enum MAPISTATUS folder_count_items(uint32_t contentcount,
                      const char *containerclass,
                      struct mailboxdata *mdata,
                      amqp_connection_state_t conn,
                      TALLOC_CTX *mem_ctx)
{
    if (contentcount == 0) return MAPI_E_SUCCESS;

    mdata->items.total += contentcount;

    if (containerclass) {
        if (!strncmp(containerclass, "IPF.Note", strlen(containerclass))) {
            mdata->items.mail += contentcount;
        } else if (!strncmp(containerclass, "IPF.StickyNote", strlen(containerclass))) {
            mdata->items.stickynote += contentcount;
        } else if (!strncmp(containerclass, "IPF.Appointment", strlen(containerclass))) {
            mdata->items.appointment += contentcount;
        } else if (!strncmp(containerclass, "IPF.Contact", strlen(containerclass))) {
            mdata->items.contact += contentcount;
        } else if (!strncmp(containerclass, "IPF.Task", strlen(containerclass))) {
            mdata->items.task += contentcount;
        } else if (!strncmp(containerclass, "IPF.Journal", strlen(containerclass))) {
            mdata->items.journal += contentcount;
        }
    } else {
        /* undefined items are always mail by default */
        mdata->items.mail += contentcount;
    }
    send_calculation(conn, mdata, mem_ctx);

    return MAPI_E_SUCCESS;
}

static enum MAPISTATUS recursive_mailbox_size(TALLOC_CTX *mem_ctx,
                          mapi_object_t *obj_store,
                          mapi_object_t *parent,
                          mapi_id_t folder_id,
                          struct mailboxdata *mdata,
                          amqp_connection_state_t conn)
{
    enum MAPISTATUS     retval = MAPI_E_SUCCESS;
    mapi_object_t       obj_folder;
    mapi_object_t       obj_table;
    struct SPropTagArray    *SPropTagArray;
    struct SRowSet      rowset;
    struct SRow     aRow;
    const uint32_t      PidTagMessageSizeVal;
    uint32_t        index;
    const uint64_t      *fid;
    const char      *name;
    const char      *containerclass;
    const uint32_t      *messagesize;
    const uint32_t      *child;
    const uint32_t      *contentcount;
    uint32_t        count;

    mapi_object_init(&obj_folder);
    retval = OpenFolder(parent, folder_id, &obj_folder);
    MAPI_RETVAL_IF(retval, retval, NULL);

    mapi_object_init(&obj_table);
    retval = GetHierarchyTable(&obj_folder, &obj_table, 0, &count);
    if (retval) {
        mapi_object_release(&obj_folder);
        return retval;
    }
    mdata->FolderCount += count;
    send_calculation(conn, mdata, mem_ctx);

    SPropTagArray = set_SPropTagArray(mem_ctx, 0x6,
                      PidTagDisplayName,
                      PidTagFolderId,
                      PidTagMessageSize,
                      PidTagFolderChildCount,
                      PidTagContainerClass,
                      PidTagContentCount);
    retval = SetColumns(&obj_table, SPropTagArray);
    MAPIFreeBuffer(SPropTagArray);
    if (retval) goto end;

    while (((retval = QueryRows(&obj_table, 0x32, TBL_ADVANCE, &rowset)) != MAPI_E_NOT_FOUND) && rowset.cRows) {
        for (index = 0; index < rowset.cRows; index++) {
            aRow = rowset.aRow[index];
            fid = (const uint64_t *) find_SPropValue_data(&aRow, PidTagFolderId);
            name = (const char *) find_SPropValue_data(&aRow, PidTagDisplayName);
            child = (const uint32_t *) find_SPropValue_data(&aRow, PidTagFolderChildCount);
            messagesize = (const uint32_t *) find_SPropValue_data(&aRow, PidTagMessageSize);
            containerclass = (const char *) find_SPropValue_data(&aRow, PidTagContainerClass);
            contentcount = (const uint32_t *) find_SPropValue_data(&aRow, PidTagContentCount);

            if (messagesize) {
                mdata->MailboxSize += *messagesize;
                send_calculation(conn, mdata, mem_ctx);
            } else {
                DEBUG(1, ("[!] PidTagMessageSize unavailable for folder %s\n", name?name:""));
                goto end;
            }

            DEBUG(3, ("[+][folder][name=\"%s\"][size=%d][children=%s][class=%s][count=%d]\n", name?name:"",
                  messagesize?*messagesize:-1, child?"yes":"no", containerclass?containerclass:"unknown",
                  contentcount?*contentcount:0));

            if (child && *child) {
                retval = recursive_mailbox_size(
                    mem_ctx, obj_store, &obj_folder, *fid, mdata, conn);
                if (retval) goto end;
            }

            /* Attachment count */
            if ((!containerclass || (containerclass && !strcmp(containerclass, "IPF.Note"))) &&
                (contentcount && *contentcount != 0)) {
                retval = folder_count_attachments(mem_ctx, obj_store,
                                                  &obj_folder, mdata, conn);
                if (retval) goto end;
            }

            /* Item counters */
            retval = folder_count_items(
                *contentcount, containerclass, mdata, conn, mem_ctx);
            if (retval) goto end;
        }
    }

end:
    mapi_object_release(&obj_table);
    mapi_object_release(&obj_folder);
    return retval;
}

static enum MAPISTATUS calculate_mailboxsize(TALLOC_CTX *mem_ctx,
                         mapi_object_t *obj_store,
                         struct mailboxdata *mdata,
                         amqp_connection_state_t conn)
{
    enum MAPISTATUS     retval;
    mapi_id_t       id_mailbox;

    /* Prpeare the recursive directory listing */
    retval = GetDefaultFolder(obj_store, &id_mailbox, olFolderTopInformationStore);
    if (retval != MAPI_E_SUCCESS) return retval;

    return recursive_mailbox_size(
        mem_ctx, obj_store, obj_store, id_mailbox, mdata, conn);

}

static void print_summary(struct mailboxdata mdata)
{
    DEBUG(0, ("[+]-------------- Mailbox Summary ----------------------------------\n"));
    DEBUG(0, ("\t* Mailbox size %"PRId64" kilobytes\n", mdata.MailboxSize/1024));
    DEBUG(0, ("\t* Total number of folders: %d\n", mdata.FolderCount));
    DEBUG(0, ("\t* Total number of items: %d\n", mdata.items.total));
    DEBUG(0, ("\t\t* Emails:              %d\n", mdata.items.mail));
    DEBUG(0, ("\t\t* Appointments:        %d\n", mdata.items.appointment));
    DEBUG(0, ("\t\t* Contacts:            %d\n", mdata.items.contact));
    DEBUG(0, ("\t\t* Tasks:               %d\n", mdata.items.task));
    DEBUG(0, ("\t\t* StickyNote:          %d\n", mdata.items.stickynote));
    DEBUG(0, ("\t\t* Journal:             %d\n", mdata.items.journal));
    DEBUG(0, ("\t* Total number of attachments:\n"));
    DEBUG(0, ("\t\t* Total number:        %d\n", mdata.items.attachments));
    DEBUG(0, ("\t\t* Total size:          %d kilobytes\n", mdata.items.attachmentSize/1024));
    DEBUG(0, ("[+]-----------------------------------------------------------------\n"));

}

int main(int argc, const char *argv[])
{
    TALLOC_CTX      *mem_ctx;
    enum MAPISTATUS     retval;
    struct mapi_session *session = NULL;
    struct mapi_context *mapi_ctx;
    struct mailboxdata  mdata;
    mapi_object_t       obj_store;
    poptContext     pc;
    int         opt;
    amqp_connection_state_t conn;
    bool            opt_dumpdata = false;
    const char      *opt_debug = NULL;
    const char      *opt_profdb = NULL;
    char            *opt_profname = NULL;
    const char      *opt_password = NULL;
    const char      *opt_username = NULL;

    enum {OPT_PROFILE_DB=1000, OPT_PROFILE, OPT_PASSWORD, OPT_USERNAME, OPT_DEBUG, OPT_DUMPDATA };

    struct poptOption long_options[] = {
        POPT_AUTOHELP
        {"database", 'f', POPT_ARG_STRING, NULL, OPT_PROFILE_DB, "set the profile database path", NULL },
        {"profile", 'p', POPT_ARG_STRING, NULL, OPT_PROFILE, "set the profile name", NULL },
        {"password", 'P', POPT_ARG_STRING, NULL, OPT_PASSWORD, "set the profile password", NULL },
        {"username", 'U', POPT_ARG_STRING, NULL, OPT_USERNAME, "specify the user's mailbox to calculate", NULL },
        {"debuglevel", 'd', POPT_ARG_STRING, NULL, OPT_DEBUG, "set the debug level", NULL },
        {"dump-data", 0, POPT_ARG_NONE, NULL, OPT_DUMPDATA, "dump the hexadecimal and NDR data", NULL },
        POPT_OPENCHANGE_VERSION
        {NULL, 0, 0, NULL, 0, NULL, NULL}
    };

    memset(&mdata, 0, sizeof(mdata));

    mem_ctx = talloc_named(NULL, 0, "mailboxsize");
    if (mem_ctx == NULL) {
        DEBUG(0, ("[!] Not enough memory\n"));
        exit(1);
    }

    pc = poptGetContext("mailboxsize", argc, argv, long_options, 0);
    while ((opt = poptGetNextOpt(pc)) != -1) {
        switch (opt) {
        case OPT_DEBUG:
            opt_debug = poptGetOptArg(pc);
            break;
        case OPT_DUMPDATA:
            opt_dumpdata = true;
            break;
        case OPT_PROFILE_DB:
            opt_profdb = poptGetOptArg(pc);
            break;
        case OPT_PROFILE:
            opt_profname = talloc_strdup(mem_ctx, poptGetOptArg(pc));
            break;
        case OPT_PASSWORD:
            opt_password = poptGetOptArg(pc);
            break;
        case OPT_USERNAME:
            opt_username = poptGetOptArg(pc);
            break;
        default:
            DEBUG(0, ("[!] Non-existent option\n"));
            exit (1);
        }
    }

    /* Sanity check on options */
    if (!opt_profdb) {
        opt_profdb = talloc_asprintf(mem_ctx, DEFAULT_PROFDB, getenv("HOME"));
    }

    /* Step 1. Initialize MAPI subsystem */
    retval = MAPIInitialize(&mapi_ctx, opt_profdb);
    if (retval != MAPI_E_SUCCESS) {
        mapi_errstr("[!] MAPIInitialize", GetLastError());
        exit (1);
    }

    /* Step 2. Set debug options */
    SetMAPIDumpData(mapi_ctx, opt_dumpdata);
    if (opt_debug) {
        SetMAPIDebugLevel(mapi_ctx, atoi(opt_debug));
    }

    /* Step 3. Profile loading */
    if (!opt_profname) {
        retval = GetDefaultProfile(mapi_ctx, &opt_profname);
        if (retval != MAPI_E_SUCCESS) {
            mapi_errstr("[!] GetDefaultProfile", GetLastError());
            exit (1);
        }
    }

    /* Step 4. Logon into EMSMDB pipe */
    retval = MapiLogonProvider(mapi_ctx, &session,
                   opt_profname, opt_password,
                   PROVIDER_ID_EMSMDB);
    if (retval != MAPI_E_SUCCESS) {
        mapi_errstr("[!] MapiLogonProvider", GetLastError());
        exit (1);
    }

    /* Step 5. Open Default Message Store */
    mapi_object_init(&obj_store);
    if (opt_username) {
        retval = OpenUserMailbox(session, opt_username, &obj_store);
        if (retval != MAPI_E_SUCCESS) {
            mapi_errstr("[!] OpenUserMailbox", GetLastError());
            exit (1);
        }
    } else {
        retval = OpenMsgStore(session, &obj_store);
        if (retval != MAPI_E_SUCCESS) {
            mapi_errstr("[!] OpenMsgStore", GetLastError());
            exit (1);
        }
    }

    /* Step 6. Calculation task and print */
    conn = get_amqp_connection();
    amqp_exchange_declare(conn, 1,
        amqp_cstring_bytes("openchange_upgrade_calculation"),
        amqp_cstring_bytes("fanout"),
        0, 0, amqp_empty_table);
    handle_amqp_error(amqp_get_rpc_reply(conn), "Declaring exchange");
    retval = calculate_mailboxsize(mem_ctx, &obj_store, &mdata, conn);
    close_amqp_connection(conn);
    if (retval) {
        mapi_errstr("mailbox", GetLastError());
        exit (1);
    }

    print_summary(mdata);

    poptFreeContext(pc);
    mapi_object_release(&obj_store);
    MAPIUninitialize(mapi_ctx);
    talloc_free(mem_ctx);

    return 0;
}

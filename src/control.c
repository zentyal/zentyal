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

#include <pthread.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <libgen.h>
#include "migrate.h"

enum rpc_command
{
    RPC_COMMAND_STATUS      = 1,
    RPC_COMMAND_EXIT        = 2,
    RPC_COMMAND_CANCEL      = 3,
    RPC_COMMAND_CONNECT     = 4,
    RPC_COMMAND_GET_USERS       = 5,
    RPC_COMMAND_SET_USERS       = 6,
    RPC_COMMAND_ESTIMATE        = 7,
    RPC_COMMAND_EXPORT      = 8,
    RPC_COMMAND_IMPORT      = 9,
};

struct rpc_command_tag
{
    unsigned int command;
    const char *tag;
};

struct rpc_command_tag tags[] = {
    { RPC_COMMAND_STATUS,       "STATUS" },
    { RPC_COMMAND_EXIT,     "EXIT" },
    { RPC_COMMAND_CANCEL,       "CANCEL" },
    { RPC_COMMAND_CONNECT,      "CONNECT" },
    { RPC_COMMAND_GET_USERS,    "GET_USERS" },
    { RPC_COMMAND_SET_USERS,    "SET_USERS" },
    { RPC_COMMAND_ESTIMATE,     "ESTIMATE" },
    { RPC_COMMAND_EXPORT,       "EXPORT" },
    { RPC_COMMAND_IMPORT,       "IMPORT" },
    { 0,                NULL },
};

/*
 * Manage state transition. Do not allow to switch states if there is an
 * ongoing operation
 */
static bool control_switch_state(struct status *status,
        enum rpc_command new_state)
{
    bool retval;
    int ret;

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("pthread_spin_lock: %s\n", strerror(ret)));
        retval = false;
        goto unlock;
    }

    /* Switch state if no currently running operations */
    switch(status->state) {
        case STATE_ESTIMATING:
        case STATE_EXPORTING:
        case STATE_IMPORTING:
            DEBUG(0, ("Cannot switch state, operation in progress\n"));
            retval = false;
            break;
        default:
            status->state = new_state;
            retval = true;
            break;
    }

unlock:
    /* Release lock */
    ret = pthread_spin_unlock(&status->lock);
    if (ret) {
        DEBUG(0, ("Can not release lock: %s\n", strerror(ret)));
        retval = false;
    }

    return retval;
}

static void control_cancel_operation(struct status *status)
{
    int ret = 0;

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("[!] pthread_spin_lock: %s\n", strerror(ret)));
        return;
    }

    /* Abort all currently running operations on thread */
    ret = pthread_cancel(status->thread_id);
    if (!ret) {
        DEBUG(0, ("[!] pthread_cancel: %s\n", strerror(ret)));
    }

    /* Release lock */
    pthread_spin_unlock(&status->lock);

    /* Wait for thread join */
    DEBUG(1, ("[*] Joining thread\n"));
    ret = pthread_join(status->thread_id, NULL);
    if (ret) {
        DEBUG(0, ("[!] pthread_join: %s\n", strerror(ret)));
    }
    DEBUG(1, ("[*] Thread joined\n"));
}



static char* control_gen_profile_name(TALLOC_CTX *mem_ctx)
{
    int i;
    char s[16];
    static const char alphanum[] =
        "0123456789"
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        "abcdefghijklmnopqrstuvwxyz";
    struct timeval tv;

    gettimeofday(&tv, NULL);

    /* Seed number for rand() */
    srand((unsigned int) tv.tv_sec + tv.tv_usec + getpid());

    for (i = 0; i < 15; ++i) {
        s[i] = alphanum[rand() % (sizeof(alphanum) - 1)];
    }

    s[15] = '\0';
    return talloc_strdup(mem_ctx, s);
}

static struct json_object *add_json_lu_object(TALLOC_CTX *mem_ctx,
                          struct json_object *json_object,
                          char *label, uint64_t value)
{
    struct json_object *new_object;
    char *tmp;

    /* Sanity checks */
    if (!json_object) return NULL;
    if (!label) return NULL;

    tmp = talloc_asprintf(mem_ctx, "%lu", value);
    if (!tmp) return NULL;

    new_object = json_object_new_string(tmp);
    json_object_object_add(json_object, label, new_object);
    talloc_free(tmp);

    return json_object;
}

bool control_init(struct status *status)
{
    bool retval = false;
    int ret = 0;

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("[!] pthread_spin_lock: %s\n", strerror(ret)));
        return false;
    }

    /* Init JSON parser */
    status->tokener = json_tokener_new();
    if (!status->tokener) {
        DEBUG(0, ("[!] No memory allocating JSON parser\n"));
        retval = false;
        goto unlock;
    }
    retval = true;

unlock:
    /* Release lock */
    pthread_spin_unlock(&status->lock);

    return retval;
}

void control_free(struct status *status)
{
    int ret = 0;

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("[!] pthread_spin_lock: %s\n", strerror(ret)));
        return;
    }

    if (status->tokener) {
        json_tokener_free(status->tokener);
    }
    status->tokener = NULL;

    /* Release lock */
    pthread_spin_unlock(&status->lock);
}


void control_abort(struct status *status)
{
    int ret = 0;

    control_cancel_operation(status);

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("[!] pthread_spin_lock: %s\n", strerror(ret)));
        return;
    }

    status->rpc_run = false;

    /* Release lock */
    pthread_spin_unlock(&status->lock);
}


struct json_object *control_handle_status(struct status *status,
                    struct json_object *jrequest)
{
    int         i       = 0;
    int         ret     = 0;
    struct json_object  *jresponse  = NULL;
    struct json_object  *user       = NULL;
    struct json_object  *user_emails    = NULL;
    struct json_object  *user_calendars = NULL;
    struct json_object  *user_contacts  = NULL;
        struct json_object  *users      = NULL;
    struct mbox_data    *mdata      = NULL;

    uint64_t        total_bytes = 0;
    uint64_t        exported_total_bytes = 0;
    uint64_t        imported_total_bytes = 0;

    uint64_t        total_items = 0;
    uint64_t        exported_total_items = 0;
    uint64_t        imported_total_items = 0;

    uint64_t        email_items = 0;
    uint64_t        exported_email_items = 0;
    uint64_t        imported_email_items = 0;

    uint64_t        email_bytes = 0;
    uint64_t        exported_email_bytes = 0;
    uint64_t        imported_email_bytes = 0;

    uint64_t        contact_bytes = 0;
    uint64_t        exported_contact_bytes = 0;
    uint64_t        imported_contact_bytes = 0;

    uint64_t        contact_items = 0;
    uint64_t        exported_contact_items = 0;
    uint64_t        imported_contact_items = 0;

    uint64_t        appointment_items = 0;
    uint64_t        exported_appointment_items = 0;
    uint64_t        imported_appointment_items = 0;

    uint64_t        appointment_bytes = 0;
    uint64_t        exported_appointment_bytes = 0;
    uint64_t        imported_appointment_bytes = 0;


    jresponse = json_object_new_object();

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("pthread_spin_lock: %s\n", strerror(ret)));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        return jresponse;
    }

    json_object_object_add(jresponse, "state", json_object_new_int(status->state));
    if (status->remote.mapi_ctx &&
        status->remote.session &&
        status->remote.server) {
        /* We are connected */
        json_object_object_add(jresponse, "remote",
            json_object_new_string(status->remote.server));
    }
    if (status->local.mapi_ctx &&
        status->local.session &&
        status->local.server) {
        /* We are connected */
        json_object_object_add(jresponse, "local",
            json_object_new_string(status->local.server));
    }


    if (status->state == STATE_ESTIMATING ||
        status->state == STATE_ESTIMATED  ||
        status->state == STATE_EXPORTING  ||
        status->state == STATE_EXPORTED   ||
        status->state == STATE_IMPORTING  ||
        status->state == STATE_IMPORTED)
    {
        users = json_object_new_array();
        json_object_object_add(jresponse, "users", users);

        for (i = 0; i < array_list_length(status->mbox_list); i++) {
            mdata = (struct mbox_data *) array_list_get_idx(status->mbox_list, i);

            total_bytes += mdata->counters.total_bytes;
            exported_total_bytes += mdata->counters.exported_total_bytes;
            imported_total_bytes += mdata->counters.imported_total_bytes;

            total_items += mdata->counters.total_items;
            exported_total_items += mdata->counters.exported_total_items;
            imported_total_items += mdata->counters.imported_total_items;

            email_items += mdata->counters.email_items;
            exported_email_items += mdata->counters.exported_email_items;
            imported_email_items += mdata->counters.imported_email_items;

            email_bytes += mdata->counters.email_bytes;
            exported_email_bytes += mdata->counters.exported_email_bytes;
            imported_email_bytes += mdata->counters.imported_email_bytes;

            appointment_items += mdata->counters.appointment_items;
            exported_appointment_items += mdata->counters.exported_appointment_items;
            imported_appointment_items += mdata->counters.imported_appointment_items;

            appointment_bytes += mdata->counters.appointment_bytes;
            exported_appointment_bytes += mdata->counters.exported_appointment_bytes;
            imported_appointment_bytes += mdata->counters.imported_appointment_bytes;

            contact_items += mdata->counters.contact_items;
            exported_contact_items += mdata->counters.exported_contact_items;
            imported_contact_items += mdata->counters.imported_contact_items;

            contact_bytes += mdata->counters.contact_bytes;
            exported_contact_bytes += mdata->counters.exported_contact_bytes;
            imported_contact_bytes += mdata->counters.imported_contact_bytes;

            user_emails = json_object_new_object();
            json_object_object_add(user_emails, "emailBytes", json_object_new_int(mdata->counters.email_bytes));
            json_object_object_add(user_emails, "emailItems", json_object_new_int(mdata->counters.email_items));
            json_object_object_add(user_emails, "exportedEmailItems", json_object_new_int(mdata->counters.exported_email_items));
            json_object_object_add(user_emails, "exportedEmailBytes", json_object_new_int(mdata->counters.exported_email_bytes));
            json_object_object_add(user_emails, "importedEmailItems", json_object_new_int(mdata->counters.imported_email_items));
            json_object_object_add(user_emails, "importedEmailBytes", json_object_new_int(mdata->counters.imported_email_bytes));

            user_contacts = json_object_new_object();
            json_object_object_add(user_contacts, "contactBytes", json_object_new_int(mdata->counters.contact_bytes));
            json_object_object_add(user_contacts, "contactItems", json_object_new_int(mdata->counters.contact_items));
            json_object_object_add(user_contacts, "exportedContactItems", json_object_new_int(mdata->counters.exported_contact_items));
            json_object_object_add(user_contacts, "exportedContactBytes", json_object_new_int(mdata->counters.exported_contact_bytes));
            json_object_object_add(user_contacts, "importedContactItems", json_object_new_int(mdata->counters.imported_contact_items));
            json_object_object_add(user_contacts, "importedContactBytes", json_object_new_int(mdata->counters.imported_contact_bytes));

            user_calendars = json_object_new_object();
            json_object_object_add(user_calendars, "appointmentBytes", json_object_new_int(mdata->counters.appointment_bytes));
            json_object_object_add(user_calendars, "appointmentItems", json_object_new_int(mdata->counters.appointment_items));
            json_object_object_add(user_calendars, "exportedAppointmentItems", json_object_new_int(mdata->counters.exported_appointment_items));
            json_object_object_add(user_calendars, "exportedAppointmentBytes", json_object_new_int(mdata->counters.exported_appointment_bytes));
            json_object_object_add(user_calendars, "importedAppointmentItems", json_object_new_int(mdata->counters.imported_appointment_items));
            json_object_object_add(user_calendars, "importedAppointmentBytes", json_object_new_int(mdata->counters.imported_appointment_bytes));

            user = json_object_new_object();
            json_object_object_add(user, "name", json_object_new_string(mdata->username));
            json_object_object_add(user, "emails", user_emails);
            json_object_object_add(user, "contacts", user_contacts);
            json_object_object_add(user, "calendars", user_calendars);

            user = add_json_lu_object(mdata, user, "startTime", mdata->start_time);
            user = add_json_lu_object(mdata, user, "endTime", mdata->end_time);
            json_object_array_add(users, user);
        }

        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "startTime", status->start_time);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "endTime", status->end_time);

        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "totalBytes", total_bytes);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "exportedTotalBytes", exported_total_bytes);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "importedTotalBytes", imported_total_bytes);

        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "totalItems", total_items);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "exportedTotalItems", exported_total_items);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "importedTotalItems", imported_total_items);

        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "emailBytes", email_bytes);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "exportedEmailBytes", exported_email_bytes);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "importedEmailBytes", imported_email_bytes);

        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "emailItems", email_items);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "exportedEmailItems", exported_email_items);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "imoprtedEmailItems", imported_email_items);

        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "appointmentBytes", appointment_bytes);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "exportedAppointmentBytes", exported_appointment_bytes);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "importedAppointmentBytes", imported_appointment_bytes);

        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "appointmentItems", appointment_items);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "exportedAppointmentItems", exported_appointment_items);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "importedAppointmentItems", imported_appointment_items);

        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "contactBytes", contact_bytes);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "exportedContactBytes", exported_contact_bytes);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "importedContactBytes", imported_contact_bytes);

        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "contactItems", contact_items);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "exportedContactItems", exported_contact_items);
        jresponse = add_json_lu_object(status->mem_ctx, jresponse, "importedContactItems", imported_contact_items);
    }

    json_object_object_add(jresponse, "code", json_object_new_int(0));

    /* Release lock */
    pthread_spin_unlock(&status->lock);

    return jresponse;
}

static uint32_t callback(struct SRowSet *rowset, void *private)
{
    uint32_t             i;
    struct SPropValue   *lpProp;
    const char          *username = (const char *)private;

    for (i = 0; i < rowset->cRows; i++) {
        lpProp = get_SPropValue_SRow(&(rowset->aRow[i]), PR_ACCOUNT);
        if (lpProp && lpProp->value.lpszA) {
            if (strcmp(lpProp->value.lpszA, username) == 0) {
                return i;
            }
        }
    }
    /* The user was not found, "abuse" of MAPI_E_USER_CANCEL error to signal
     * it.
     */
    return rowset->cRows;
}

static bool connect_to_server(TALLOC_CTX *mem_ctx,
                struct connection *conn,
                const char *profdb,
                const char *username,
                const char *password,
                const char *address,
                const char *workstation)
{
    enum MAPISTATUS     retval;
    char            *profname = NULL;
    char            *cpid_str;
    char            *lcid_str;
    const char      *locale;
    const char      *defaultldifpath;
    char            *profdbcopy;
    char            errorbuffer[256];
    int             error;
    struct mapi_profile *profile = NULL;

    /* If mapi context is initialized, close and reconnect */
    if (conn->mapi_ctx) {
        MAPIUninitialize(conn->mapi_ctx);
        talloc_free(conn->server);
        conn->server = NULL;
        conn->session = NULL;
        conn->mapi_ctx = NULL;
    }

    /* Generate random profile name */
    profname = control_gen_profile_name(mem_ctx);
    profile = talloc_zero(mem_ctx, struct mapi_profile);

    DEBUG(0, ("Preparing Profile Store at %s\n", profdb));
    /* Creates an initial profile store if it doesn't exist yet */
    if (access(profdb, F_OK) != 0) {
        DEBUG(2, ("Creating Profile Store at %s...\n", profdb));
        profdbcopy = talloc_strdup(mem_ctx, profdb);
        error = mkdir(dirname(profdbcopy), 0700);
        talloc_free(profdbcopy);
        if ((error == -1) && (errno != EEXIST)) {
            conn->error = talloc_asprintf(
                mem_ctx, "mkdir: %s", strerror_r(error, errorbuffer, 256));
                goto fail;
        }

        defaultldifpath = talloc_strdup(mem_ctx, mapi_profile_get_ldif_path());
        retval = CreateProfileStore(profdb, defaultldifpath);
        if (retval != MAPI_E_SUCCESS) {
                conn->error = talloc_asprintf(
                    mem_ctx, "CreateProfileStore: %s",
                    mapi_get_errstr(GetLastError()));
                goto fail;
        }
    }

    /* Initialize MAPI subsystem */
    DEBUG(2, ("Initialising Profile Store at %s...\n", profdb));
    retval = MAPIInitialize(&conn->mapi_ctx, profdb);
    if (retval != MAPI_E_SUCCESS) {
        conn->error = talloc_asprintf(mem_ctx, "MAPIInitialize: %s",
            mapi_get_errstr(GetLastError()));
        goto fail;
    }

    /* Set debug options */
    SetMAPIDumpData(conn->mapi_ctx, conn->dumpdata);
    if (conn->debug_level) {
        SetMAPIDebugLevel(conn->mapi_ctx, conn->debug_level);
    }

    /* Try to open the profile, check it not exists */
    retval = OpenProfile(conn->mapi_ctx, profile, profname, NULL);
    if (retval == MAPI_E_SUCCESS) {
        conn->error = talloc_asprintf(mem_ctx, "OpenProfile: profile already exists");
        goto fail;
    }

    /* Create the profile, do not store password */
    retval = CreateProfile(conn->mapi_ctx, profname, username, password, 1);
    if (retval != MAPI_E_SUCCESS) {
        conn->error = talloc_asprintf(mem_ctx, "CreateProfile: %s",
            mapi_get_errstr(GetLastError()));
        goto fail;
    }
    DEBUG(4, ("[*] Profile '%s' created for user '%s' on '%s'\n",
              profname, username, profdb));

    /* Fill some options */
    mapi_profile_add_string_attr(conn->mapi_ctx, profname, "binding", address);
    mapi_profile_add_string_attr(conn->mapi_ctx, profname, "seal", "false");
    mapi_profile_add_string_attr(conn->mapi_ctx, profname, "kerberos", "false");
    mapi_profile_add_string_attr(conn->mapi_ctx, profname, "workstation", workstation);

    locale = (const char *) mapi_get_system_locale();
    cpid_str = talloc_asprintf(mem_ctx, "%d", mapi_get_cpid_from_locale(locale));
    lcid_str = talloc_asprintf(mem_ctx, "%d", mapi_get_lcid_from_locale(locale));
    mapi_profile_add_string_attr(conn->mapi_ctx, profname, "codepage", cpid_str);
    mapi_profile_add_string_attr(conn->mapi_ctx, profname, "language", lcid_str);
    mapi_profile_add_string_attr(conn->mapi_ctx, profname, "method", lcid_str);
    talloc_free(cpid_str);
    talloc_free(lcid_str);

    /* Login into NSPI pipe */
    retval = MapiLogonProvider(conn->mapi_ctx, &conn->session, profname,
                   password, PROVIDER_ID_NSPI);
    if (retval != MAPI_E_SUCCESS) {
        conn->error = talloc_asprintf(mem_ctx, "MapiLogonProvider: %s",
            mapi_get_errstr(GetLastError()));
        goto fail;
    }

    retval = ProcessNetworkProfile(conn->session, username,
                                   (mapi_profile_callback_t) callback,
                                   username);
    if (retval != MAPI_E_SUCCESS && retval != 0x1) {
        if (retval == MAPI_E_USER_CANCEL) {
            conn->error = talloc_asprintf(mem_ctx,
                "ProcessNetworkProfile: We had a problem looking up '%s' user",
                username);
        } else {
            conn->error = talloc_asprintf(mem_ctx, "ProcessNetworkProfile: %s",
                mapi_get_errstr(GetLastError()));
        }
        goto fail;
    }

    /* Reset the context, the profile is ready */
    MAPIUninitialize(conn->mapi_ctx);
    conn->server = NULL;
    conn->session = NULL;
    conn->mapi_ctx = NULL;

    /* Initialize again MAPI subsystem */
    retval = MAPIInitialize(&conn->mapi_ctx, profdb);
    if (retval != MAPI_E_SUCCESS) {
        conn->error = talloc_asprintf(mem_ctx, "ProcessNetworkProfile: %s",
            mapi_get_errstr(GetLastError()));
        goto fail;
    }

    /* Set debug options */
    SetMAPIDumpData(conn->mapi_ctx, conn->dumpdata);
    if (conn->debug_level) {
        SetMAPIDebugLevel(conn->mapi_ctx, conn->debug_level);
    }

    /* Logon into EMSMDB pipe */
    retval = MapiLogonEx(conn->mapi_ctx, &conn->session,
                 profname, password);
    if (retval != MAPI_E_SUCCESS || !conn->session) {
        conn->error = talloc_asprintf(mem_ctx, "MapiLogonEx: %s",
            mapi_get_errstr(GetLastError()));
        goto fail;
    }
    DEBUG(1, ("Logged in to address %s\n", address));

    /* We are connected now */
    conn->server = talloc_strdup(mem_ctx, address);

    talloc_free(profname);

    return true;
fail:
    if (conn->mapi_ctx) {
        DeleteProfile(conn->mapi_ctx, profname);
        MAPIUninitialize(conn->mapi_ctx);
        if (conn->server) {
            talloc_free(conn->server);
        }
        conn->server = NULL;
        conn->session = NULL;
        conn->mapi_ctx = NULL;
    }
    talloc_free(profname);
    return false;
}

/*
 * Command to connect to server
 */
static struct json_object *control_handle_connect(struct status *status,
                        struct json_object *jrequest)
{
    struct json_object  *jresponse;
    struct json_object  *remote_jusername;
    struct json_object  *remote_jpassword;
    struct json_object  *remote_jaddress;
    struct json_object  *local_jusername;
    struct json_object  *local_jpassword;
    struct json_object  *local_jaddress;
    char workstation[256];
    int ret = 0;

    jresponse = json_object_new_object();

    /* Validate command arguments */
    struct json_object *jremote = json_object_object_get(jrequest, "remote");
    if (!jremote) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Missing remote key"));
        return jresponse;
    }

    struct json_object *jlocal = json_object_object_get(jrequest, "local");
    if (!jlocal) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Missing local key"));
        return jresponse;
    }

    remote_jusername = json_object_object_get(jremote, "username");
    if (!remote_jusername) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Missing remote username key"));
        return jresponse;
    }

    remote_jpassword = json_object_object_get(jremote, "password");
    if (!remote_jpassword) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Missing remote password key"));
        return jresponse;
    }

    remote_jaddress = json_object_object_get(jremote, "address");
    if (!remote_jaddress) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Missing remote address key"));
        return jresponse;
    }

    local_jusername = json_object_object_get(jlocal, "username");
    if (!local_jusername) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Missing local username key"));
        return jresponse;
    }

    local_jpassword = json_object_object_get(jlocal, "password");
    if (!local_jpassword) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Missing local password key"));
        return jresponse;
    }

    local_jaddress = json_object_object_get(jlocal, "address");
    if (!local_jaddress) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Missing local address key"));
        return jresponse;
    }

    /* Get hostname */
    gethostname(workstation, sizeof(workstation) - 1);
    workstation[sizeof(workstation) - 1] = 0;

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("[!] pthread_spin_lock: %s\n", strerror(ret)));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        return jresponse;
    }

    /* Connect to remote server */
    DEBUG(4, ("[*] Connecting to remote server\n"));
    char *remote_username = talloc_strdup(status->mem_ctx, json_object_get_string(remote_jusername));
    char *remote_password = talloc_strdup(status->mem_ctx, json_object_get_string(remote_jpassword));
    char *remote_address  = talloc_strdup(status->mem_ctx, json_object_get_string(remote_jaddress));
    if(!connect_to_server(status->mem_ctx, &status->remote, status->opt_profdb,
        remote_username, remote_password, remote_address, workstation)) {
        char *error = talloc_asprintf(status->mem_ctx,
            "Error connecting to remote server. %s", status->remote.error);
        DEBUG(0, ("[!] %s\n", error));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string(error));
        talloc_free(error);
        talloc_free(status->remote.error);
        status->remote.error = NULL;
        goto unlock;
    }
    talloc_free(remote_username);
    talloc_free(remote_password);
    talloc_free(remote_address);

    /* Connect to local server */
    DEBUG(4, ("[*] Connecting to local server\n"));
    char *local_username = talloc_strdup(status->mem_ctx, json_object_get_string(local_jusername));
    char *local_password = talloc_strdup(status->mem_ctx, json_object_get_string(local_jpassword));
    char *local_address  = talloc_strdup(status->mem_ctx, json_object_get_string(local_jaddress));
    if (!connect_to_server(status->mem_ctx, &status->local, status->opt_profdb,
        local_username, local_password, local_address, workstation)) {
        char *error = talloc_asprintf(status->mem_ctx,
            "Error connecting to local server. %s", status->local.error);
        DEBUG(0, ("[!] %s\n", error));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string(error));
        talloc_free(error);
        talloc_free(status->local.error);
        status->local.error = NULL;
        goto unlock;
    }
    talloc_free(local_username);
    talloc_free(local_password);
    talloc_free(local_address);

    json_object_object_add(jresponse, "code", json_object_new_int(0));

unlock:
    /* Release lock */
    pthread_spin_unlock(&status->lock);

    return jresponse;
}

struct json_object *control_handle_estimate(struct status *status, struct json_object *jrequest)
{
    struct json_object  *jresponse;
    struct json_object  *jusers;
        struct json_object  *juser;
    struct json_object  *username;
    array_list      *users;
        struct mbox_data    *mdata;
    int         i;
    int             ret = 0;

    jresponse = json_object_new_object();
    jusers = json_object_object_get(jrequest, "users");
    if (!jusers) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Empty users list"));
        return jresponse;
    }

    users = json_object_get_array(jusers);
    if (!users) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Empty user list"));
        return jresponse;
    }

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("[!] pthread_spin_lock: %s\n", strerror(ret)));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        return jresponse;
    }

    /* Free the previous user list if any */
    status->start_time = 0;
    status->end_time = 0;
    if (status->mbox_list) {
        array_list_free(status->mbox_list);
    }
    status->mbox_list = array_list_new(estimate_data_free);

    /* Add users to list to estimate */
    for (i = 0; i < array_list_length(users); i++) {
        juser = (struct json_object *) array_list_get_idx(users, i);
        username = json_object_object_get(juser, "name");
        if (!username) {
            json_object_object_add(jresponse, "code", json_object_new_int(1));
            json_object_object_add(jresponse, "error", json_object_new_string("Missing name entry"));
            goto unlock;
        }

        mdata = talloc_zero(status->mem_ctx, struct mbox_data);
        mdata->username = talloc_strdup(mdata, json_object_get_string(username));

        array_list_add(status->mbox_list, mdata);
        DEBUG(0, ("[*] Added user %s for estimation\n", mdata->username));
    }
    DEBUG(0, ("[*] Added %d users for estimation\n", array_list_length(status->mbox_list)));

    /* Begin estimation on thread */
    i = pthread_create(&status->thread_id, NULL, &estimate_start_thread, status);
    if (i != 0) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_int(i));
        goto unlock;
    }

    json_object_object_add(jresponse, "code", json_object_new_int(0));

unlock:
    /* Release lock */
    pthread_spin_unlock(&status->lock);

    return jresponse;
}

struct json_object *control_handle_export(struct status *status, struct json_object *jrequest)
{
    struct json_object  *jresponse;
    int         i = 0;
    int             ret = 0;

    jresponse =  json_object_new_object();

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("[!] pthread_spin_lock: %s\n", strerror(ret)));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        return jresponse;
    }

    /* Begin export thread */
    i = pthread_create(&status->thread_id, NULL, &export_start_thread, status);
    if (i != 0) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_int(i));
        goto unlock;
    }

    json_object_object_add(jresponse, "code", json_object_new_int(0));
unlock:
    /* Release lock */
    pthread_spin_unlock(&status->lock);

    return jresponse;
}

struct json_object *control_handle_import(struct status *status, struct json_object *jrequest)
{
    struct json_object  *jresponse;
    int         i = 0;
    int             ret = 0;

    jresponse = json_object_new_object();

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("[!] pthread_spin_lock: %s\n", strerror(ret)));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        return jresponse;
    }

    /* Begin import thread */
    i = pthread_create(&status->thread_id, NULL, &import_start_thread, status);
    if (i != 0) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_int(i));
        goto unlock;
    }

    json_object_object_add(jresponse, "code", json_object_new_int(0));

unlock:
    /* Release lock */
    pthread_spin_unlock(&status->lock);

    return jresponse;
}


struct json_object *control_handle_cancel(struct status *status, struct json_object *jrequest)
{
    struct json_object  *jresponse;

    jresponse = json_object_new_object();

    /* TODO Cancel current operation */

    return jresponse;
}


struct json_object *control_handle_get_users(struct status *status, struct json_object *jrequest)
{
    struct json_object  *jresponse;
    struct json_object  *jlist;
    struct SPropTagArray    *SPropTagArray;
    struct PropertyRowSet_r *RowSet;
    uint32_t        count;
    uint8_t         ulFlags;
    uint32_t        rowsFetched = 0;
    uint32_t        totalRecs = 0;
    uint32_t        i = 0;
    int             ret = 0;
    enum MAPISTATUS mapiretval;

    jresponse = json_object_new_object();

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("[!] pthread_spin_lock: %s\n", strerror(ret)));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        return jresponse;
    }

    mapiretval = GetGALTableCount(status->remote.session, &totalRecs);
    if (mapiretval != MAPI_E_SUCCESS) {
        DEBUG(0, ("[!] Error counting the number of users: %s\n",
                  mapi_get_errstr(mapiretval)));
        totalRecs = 0;
    }
    json_object_object_add(jresponse, "count", json_object_new_int(totalRecs));
    DEBUG(4, ("[*] Total Number of entries in GAL: %d\n", totalRecs));
    if (totalRecs <= 0 ) {
        json_object_object_add(jresponse, "code", json_object_new_int(0));
        goto unlock;
    }

    jlist = json_object_new_array();
    json_object_object_add(jresponse, "entries", jlist);

    SPropTagArray = set_SPropTagArray(status->mem_ctx, 0xc,
                      PR_INSTANCE_KEY,
                      PR_ENTRYID,
                      PR_DISPLAY_NAME_UNICODE,
                      PR_EMAIL_ADDRESS_UNICODE,
                      PR_DISPLAY_TYPE,
                      PR_OBJECT_TYPE,
                      PR_ADDRTYPE_UNICODE,
                      PR_OFFICE_TELEPHONE_NUMBER_UNICODE,
                      PR_OFFICE_LOCATION_UNICODE,
                      PR_TITLE_UNICODE,
                      PR_COMPANY_NAME_UNICODE,
                      PR_ACCOUNT_UNICODE);

    count = 0x7;
    ulFlags = TABLE_START;
    do {
        count += 0x2;
        GetGALTable(status->remote.session, SPropTagArray, &RowSet, count, ulFlags);
        if ((!RowSet) || (!(RowSet->aRow))) {
            json_object_object_add(jresponse, "code", json_object_new_int(1));
            MAPIFreeBuffer(SPropTagArray);
            goto unlock;
        }
        rowsFetched = RowSet->cRows;
        if (rowsFetched) {
            for (i = 0; i < rowsFetched; i++) {
                struct json_object  *jentry;
                struct PropertyRow_r    *aRow = &RowSet->aRow[i];
                const char      *addrtype;
                const char      *name;
                const char      *email;
                const char      *account;

                if (aRow) {
                    jentry = json_object_new_object();
                    addrtype = (const char *) find_PropertyValue_data(aRow, PR_ADDRTYPE_UNICODE);
                    json_object_object_add(jentry, "addrtype", json_object_new_string(addrtype));

                    name = (const char *) find_PropertyValue_data(aRow, PR_DISPLAY_NAME_UNICODE);
                    json_object_object_add(jentry, "name", json_object_new_string(name));

                    email = (const char *) find_PropertyValue_data(aRow, PR_EMAIL_ADDRESS_UNICODE);
                    json_object_object_add(jentry, "email", json_object_new_string(email));

                    account = (const char *) find_PropertyValue_data(aRow, PR_ACCOUNT_UNICODE);
                    json_object_object_add(jentry, "account", json_object_new_string(account));
                    DEBUG(4, ("[%s] %s:\n\tName: %-25s\n\tEmail: %-25s\n",
                          addrtype, account, name, email));
                    json_object_array_add(jlist, jentry);
                }
            }
        }
        ulFlags = TABLE_CUR;
        MAPIFreeBuffer(RowSet);
    } while (rowsFetched == count);

    MAPIFreeBuffer(SPropTagArray);

    json_object_object_add(jresponse, "code", json_object_new_int(0));

unlock:
    /* Release lock */
    pthread_spin_unlock(&status->lock);

    return jresponse;
}

amqp_bytes_t control_handle(struct status *status, amqp_bytes_t request)
{
    struct json_object  *jrequest;
    struct json_object  *jresponse;
    struct json_object  *jcommand;
    char            *response;
    int             ret = 0;

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        DEBUG(0, ("[!] pthread_spin_lock: %s\n", strerror(ret)));
        return amqp_cstring_bytes("{ \"code\": 1, \"error\":\"Error adquiring lock\" }");
    }

    /* Reset tokener */
    json_tokener_reset(status->tokener);

    /* Parse buffer */
    jrequest = json_tokener_parse_ex(status->tokener, request.bytes, request.len);
    if (!jrequest) {
        DEBUG(0, ("[!] Error parsing json command\n"));
        return amqp_cstring_bytes("{ \"code\": 1, \"error\":\"Error parsing JSON request\" }");    /* request parse error */
    }

    /* Release lock */
    pthread_spin_unlock(&status->lock);

    jcommand = json_object_object_get(jrequest, "command");
    if (!jcommand) {
        return amqp_cstring_bytes("{\"code\": 1, \"error\": \"Missing command key\" }"); /* unknown command */
    }
    switch (json_object_get_int(json_object_object_get(jrequest, "command"))) {
        case RPC_COMMAND_STATUS:
        DEBUG(0, ("[*] Received status command\n"));
        jresponse = control_handle_status(status, jrequest);
        break;
        case RPC_COMMAND_CONNECT:
        DEBUG(0, ("[*] Received connect command\n"));
        jresponse = control_handle_connect(status, jrequest);
        break;
        case RPC_COMMAND_ESTIMATE:
        DEBUG(0, ("[*] Received estimate command\n"));
        jresponse = control_handle_estimate(status, jrequest);
        break;
        case RPC_COMMAND_EXPORT:
        DEBUG(0, ("[*] Received export command\n"));
        jresponse = control_handle_export(status, jrequest);
        break;
        case RPC_COMMAND_IMPORT:
        DEBUG(0, ("[*] Received import command\n"));
        jresponse = control_handle_import(status, jrequest);
        break;
        case RPC_COMMAND_GET_USERS:
        DEBUG(0, ("[*] Received user list command\n"));
        jresponse = control_handle_get_users(status, jrequest);
        break;
        case RPC_COMMAND_CANCEL:
        DEBUG(0, ("[*] Received cancel command\n"));
        jresponse = control_handle_cancel(status, jrequest);
        break;
    case RPC_COMMAND_EXIT:
        DEBUG(0, ("[*] Received %s (%d) command\n",
            tags[RPC_COMMAND_EXIT].tag,
            RPC_COMMAND_EXIT));
        default:
        return amqp_cstring_bytes("{\"code\": 1}"); /* unknown command */
    }

    response = strdup(json_object_to_json_string(jresponse));
    DEBUG(0, ("[*] response to command: '%s' \n", response));

    return amqp_cstring_bytes(response);
}

#include <inttypes.h>
#include <time.h>
#include <stdbool.h>
#include <stdlib.h>
#include <libmapi/libmapi.h>
#include <libocpf/ocpf.h>
#include <json/json.h>

#include "migrate.h"
#include "control.h"

bool control_init(struct status *status)
{
    /* Init JSON parser */
    status->tokener = json_tokener_new();
    if (!status->tokener) {
        DEBUG(0, ("[!] No memory allocating JSON parser\n"));
        return false;
    }
    return true;
}

void control_free(struct status *status)
{
    if (status->tokener) {
        json_tokener_free(status->tokener);
    }
    status->tokener = NULL;
}

void control_abort(struct status *status)
{
    status->rpc_run = false;
    // Abort all currently running operations on thread TODO
}

json_object* control_handle_status(struct status *status, json_object *jrequest)
{
    json_object *jresponse = json_object_new_object();
    json_object_object_add(jresponse, "code", json_object_new_int(0));
    json_object_object_add(jresponse, "state", json_object_new_int(status->state));
    return jresponse;
}

/*
 * Command to connect to server
 */
json_object* control_handle_connect(struct status *status, json_object *jrequest)
{
    enum MAPISTATUS retval;
    struct mapi_profile *profile;
    json_object *jresponse = json_object_new_object();

    json_object *jusername = json_object_object_get(jrequest, "username");
    if (!jusername) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Missing username key"));
        return jresponse;
    }
    json_object *jpassword = json_object_object_get(jrequest, "password");
    if (!jpassword) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Missing password key"));
        return jresponse;
    }
    json_object *jaddress = json_object_object_get(jrequest, "address");
    if (!jaddress) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Missing address key"));
        return jresponse;
    }

    /* Get hostname */
    char hostname[256];
    gethostname(hostname, sizeof(hostname) - 1);
    hostname[sizeof(hostname) - 1] = 0;

    /* Generate random profile name */
    char *profname = talloc_asprintf(status->mem_ctx, "%lu", (uint64_t)time(NULL));

    /* Initialize MAPI subsystem */
    retval = MAPIInitialize(&status->mapi_ctx, status->opt_profdb);
    if (retval != MAPI_E_SUCCESS) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] MAPIInitialize %s\n", error));
        json_object_object_add(jresponse, "code", json_object_new_int(-1));
        json_object_object_add(jresponse, "mapistatus", json_object_new_int(retval));
        json_object_object_add(jresponse, "mapierror", json_object_new_string(error));
        talloc_free(profname);
        return jresponse;
    }

    /* Set debug options */
    SetMAPIDumpData(status->mapi_ctx, status->opt_dumpdata);
    if (status->opt_debug) {
        SetMAPIDebugLevel(status->mapi_ctx, status->opt_debug);
    }

    /* Instantiate and fill profile */
    profile = talloc(status->mem_ctx, struct mapi_profile);
    retval = OpenProfile(status->mapi_ctx, profile, profname, NULL);
    if (retval == MAPI_E_SUCCESS) {
        DEBUG(0, ("[!] OpenProfile: profile \"%s\" already exists\n", profname));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Created profile already exists"));
        talloc_free(profname);
        return jresponse;
    }

    retval = CreateProfile(status->mapi_ctx, profname,
        json_object_get_string(jusername),
        json_object_get_string(jpassword), 1); /* No pass on profile */
    if (retval != MAPI_E_SUCCESS) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] CreateProfile: %s\n", error));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string(error));
        talloc_free(profname);
        return jresponse;
    }

    mapi_profile_add_string_attr(status->mapi_ctx, profname, "binding",
            json_object_get_string(jaddress));
    mapi_profile_add_string_attr(status->mapi_ctx, profname, "seal",
            "false");
    mapi_profile_add_string_attr(status->mapi_ctx, profname, "kerberos",
            "false");
    mapi_profile_add_string_attr(status->mapi_ctx, profname, "workstation",
            hostname);


    const char *locale = (const char *) mapi_get_system_locale();
    uint32_t cpid = mapi_get_cpid_from_locale(locale);
    uint32_t lcid = mapi_get_lcid_from_locale(locale);
    char *cpid_str = talloc_asprintf(status->mem_ctx, "%d", cpid);
    char *lcid_str = talloc_asprintf(status->mem_ctx, "%d", lcid);
    mapi_profile_add_string_attr(status->mapi_ctx, profname, "codepage", cpid_str);
    mapi_profile_add_string_attr(status->mapi_ctx, profname, "language", lcid_str);
    mapi_profile_add_string_attr(status->mapi_ctx, profname, "method", lcid_str);

    retval = MapiLogonProvider(status->mapi_ctx, &status->session, profname,
        json_object_get_string(jpassword), PROVIDER_ID_NSPI);
    if (retval != MAPI_E_SUCCESS) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] MapiLogonProvider NSPI: %s\n", error));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string(error));
        DeleteProfile(status->mapi_ctx, profname);
        talloc_free(profname);
        return jresponse;
    }

    retval = ProcessNetworkProfile(status->session,
        json_object_get_string(jusername), NULL, NULL);
    if (retval != MAPI_E_SUCCESS && retval != 0x1) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] ProcessNetworkProfile: %s\n", error));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string(error));
        DeleteProfile(status->mapi_ctx, profname);
        talloc_free(profname);
        return jresponse;
    }

    MAPIUninitialize(status->mapi_ctx);
    status->session = NULL;
    status->mapi_ctx = NULL;

    /* Initialize MAPI subsystem */
    retval = MAPIInitialize(&status->mapi_ctx, status->opt_profdb);
    if (retval != MAPI_E_SUCCESS) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] MAPIInitialize %s\n", error));
        json_object_object_add(jresponse, "code", json_object_new_int(-1));
        json_object_object_add(jresponse, "mapistatus", json_object_new_int(retval));
        json_object_object_add(jresponse, "mapierror", json_object_new_string(error));
        talloc_free(profname);
        return jresponse;
    }

    /* Set debug options */
    SetMAPIDumpData(status->mapi_ctx, status->opt_dumpdata);
    if (status->opt_debug) {
        SetMAPIDebugLevel(status->mapi_ctx, status->opt_debug);
    }

    /* Logon into EMSMDB pipe */
    DEBUG(0, ("Login with profile: %s\n", profname));
    retval = MapiLogonProvider(status->mapi_ctx, &status->session,
                   profname, json_object_get_string(jpassword),
                   PROVIDER_ID_EMSMDB);
    if (retval != MAPI_E_SUCCESS) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] ProcessNetworkProfile: %s\n", error));
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string(error));
        //DeleteProfile(status->mapi_ctx, profname);
        talloc_free(profname);
        return jresponse;
    }

    json_object_object_add(jresponse, "code", json_object_new_int(0));
    json_object_object_add(jresponse, "mapistatus", json_object_new_int(retval));

    return jresponse;
}

json_object* control_handle_estimate(struct status *status, json_object *jrequest)
{
    int i;
    json_object *jresponse = json_object_new_object();
    json_object *jusers = json_object_object_get(jrequest, "users");
    array_list *users = json_object_get_array(jusers);
    if (!users) {
        json_object_object_add(jresponse, "code", json_object_new_int(1));
        json_object_object_add(jresponse, "error", json_object_new_string("Empty user list"));
        return jresponse;
    }

    /* Free the previous user list if any */
    if (status->mbox_list) {
        array_list_free(status->mbox_list);
    }
    status->mbox_list = array_list_new(mbox_data_free);

    /* Add users to list to estimate */
    for (i=0; i<array_list_length(users); i++) {
        struct json_object *juser =
            (struct json_object *) array_list_get_idx(users, i);
        json_object *username = json_object_object_get(juser, "name");

        struct mbox_data *data = talloc_zero(status->mem_ctx, struct mbox_data);
        data->username = talloc_strdup(data, json_object_get_string(username));

        array_list_add(status->mbox_list, data);
        DEBUG(0, ("[*] Added user %s for estimation\n", data->username));
    }
    DEBUG(0, ("[*] Added %d users for estimation\n", array_list_length(status->mbox_list)));

    /* Begin estimation on thread */
    i = pthread_create(&status->thread_id, NULL, &mbox_start_estimate_thread, status);
    if (i != 0) {
        //handle_error_en(s, "pthread_create");
    }

    json_object_object_add(jresponse, "code", json_object_new_int(0));

    return jresponse;
}

json_object* control_handle_migrate(struct status *status, json_object *jrequest)
{
    json_object *jresponse = json_object_new_object();

//    /* Begin migration on thread */
//
//    /* Step 7. Mailbox items extraction */
//    retval = export_mailbox(mem_ctx, &obj_store, &mdata, conn);
//    close_amqp_connection(conn);
//    if (retval) {
//        mapi_errstr("mailbox", GetLastError());
//        exit (1);
//    }
//        mapi_object_release(&obj_store);
//
//    MAPIUninitialize(mapi_ctx);
//    disconnect

    return jresponse;
}

json_object* control_handle_cancel(struct status *status, json_object *jrequest)
{
    json_object *jresponse = json_object_new_object();

    /* Cancel current operation */

    return jresponse;
}

amqp_bytes_t control_handle(struct status *status, amqp_bytes_t request)
{
    json_object *jrequest, *jresponse;

    /* Reset tokener */
    json_tokener_reset(status->tokener);

    /* Parse buffer */
    jrequest = json_tokener_parse_ex(status->tokener, request.bytes, request.len);
    if (!jrequest) {
        DEBUG(0, ("[!] Error parsing json command\n"));
        return amqp_cstring_bytes("{ \"code\": 1 }");    /* request parse error */
    }

    switch (json_object_get_int(json_object_object_get(jrequest, "command"))) {
        case 0:
            DEBUG(0, ("[*] Received status command\n"));
            jresponse = control_handle_status(status, jrequest);
            break;
        case 1:
            DEBUG(0, ("[*] Received connect command\n"));
            jresponse = control_handle_connect(status, jrequest);
            break;
        case 2:
            DEBUG(0, ("[*] Received estimate command\n"));
            jresponse = control_handle_estimate(status, jrequest);
            break;
        case 3:
            DEBUG(0, ("[*] Received migrate command\n"));
            jresponse = control_handle_migrate(status, jrequest);
            break;
        case 4:
            DEBUG(0, ("[*] Received cancel command\n"));
            jresponse = control_handle_cancel(status, jrequest);
            break;
        default:
            return amqp_cstring_bytes("{\"code\": -2}"); /* unknown command */
    }

    const char *response = strdup(json_object_to_json_string(jresponse));
    DEBUG(0, ("[*] response to command: '%s' \n", response));
    json_object_put(jrequest);
    json_object_put(jresponse);
    return amqp_cstring_bytes(response);
}

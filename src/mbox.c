#include <stdio.h>
#include <inttypes.h>
#include <json/json.h>
#include <libmapi/libmapi.h>

#include "migrate.h"

#if 0
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

static bool messages_dump(TALLOC_CTX *mem_ctx, mapi_object_t *obj_store,
                          mapi_object_t *parent,
                          struct mailboxtreeitem *folder,
                          struct mailboxdata *mdata,
                          amqp_connection_state_t conn)
{
    enum MAPISTATUS retval;
    int ret;
    mapi_object_t   obj_folder;
    mapi_object_t   obj_message;
    mapi_id_t   id_tis;
    char    *filename = NULL;
    struct mapi_SPropValue_array    lpProps;
    uint32_t    context_id;
    mapi_object_t   obj_htable;
    struct SPropTagArray    *SPropTagArray;
    struct SRowSet  SRowSet;
    uint32_t    i;
    const uint64_t  *fid;
    const uint64_t  *mid;

    /* Step 1. search the folder from Top Information Store */
    mapi_object_init(&obj_folder);
    retval = OpenFolder(parent, folder->id, &obj_folder);
    MAPI_RETVAL_IF(retval, retval, NULL);

    /* Step 2. search the messages */
    mapi_object_init(&obj_message);
    mapi_object_init(&obj_htable);
    retval = GetContentsTable(&obj_folder, &obj_htable, 0, NULL);
    if (retval != MAPI_E_SUCCESS) return false;

    SPropTagArray = set_SPropTagArray(mem_ctx, 0x2, PR_FID, PR_MID);
    retval = SetColumns(&obj_htable, SPropTagArray);
    MAPIFreeBuffer(SPropTagArray);
    if (retval != MAPI_E_SUCCESS) return false;

    while (((retval = QueryRows(&obj_htable, 0x32, TBL_ADVANCE, &SRowSet)) != MAPI_E_NOT_FOUND) && SRowSet.cRows) {
        for (i = 0; i < SRowSet.cRows; i++) {
            fid = (const uint64_t *)find_SPropValue_data(&SRowSet.aRow[i], PR_FID);
            mid = (const uint64_t *)find_SPropValue_data(&SRowSet.aRow[i], PR_MID);
            retval = OpenMessage(&obj_folder, *fid, *mid, &obj_message, ReadWrite);
            if (retval != MAPI_E_SUCCESS) {
                mapi_object_release(&obj_htable);
                return false;
            }
            /* Step 3. retrieve all message properties */
            retval = GetPropsAll(&obj_message, MAPI_UNICODE, &lpProps);

            /* Step 4. save the message */
            ret = ocpf_init();

            filename = talloc_asprintf(
                mem_ctx, "%s/%" PRIu64 ".ocpf", folder->path, *mid);
            DEBUG(0, ("OCPF output file: %s\n", filename));

            ret = ocpf_new_context(filename, &context_id, OCPF_FLAGS_CREATE);
            talloc_free(filename);
            ret = ocpf_write_init(context_id, folder->id);

            ret = ocpf_write_auto(context_id, &obj_message, &lpProps);
            if (ret == OCPF_SUCCESS) {
                ret = ocpf_write_commit(context_id);
            }

            ret = ocpf_del_context(context_id);

            ret = ocpf_release();
        }
    }

    mapi_object_release(&obj_htable);
    mapi_object_release(&obj_message);
    mapi_object_release(&obj_folder);

    return true;
}

static enum MAPISTATUS recursive_mailbox_export(TALLOC_CTX *mem_ctx,
                                                mapi_object_t *obj_store,
                                                mapi_object_t *parent,
                                                struct mailboxtreeitem *folder,
                                                struct mailboxdata *mdata,
                                                amqp_connection_state_t conn)
{
    enum MAPISTATUS     retval = MAPI_E_SUCCESS;
    mapi_object_t       obj_folder;
    int ret;
    struct mailboxtreeitem *element;

    mapi_object_init(&obj_folder);
    retval = OpenFolder(parent, folder->id, &obj_folder);
    MAPI_RETVAL_IF(retval, retval, NULL);

    ret = create_directory(folder->path);
    if (ret != 0) {
        return MAPI_E_UNABLE_TO_COMPLETE;
    }

    messages_dump(mem_ctx, obj_store, parent, folder, mdata, conn);

    for (element = folder->children; element && element->next; element = element->next) {
        retval = recursive_mailbox_export(
            mem_ctx, obj_store, &obj_folder, element, mdata, conn);
        if (retval) goto end;
    }

end:
    mapi_object_release(&obj_folder);
    return retval;
}

int create_directory(const char *path)
{
    int retval;
    struct stat sb;

    DEBUG(3, ("[+] Creating the directory %s\n", path));
    retval = stat(path, &sb);
    if (retval == 0) {
        if (sb.st_mode & S_IFDIR)
            return 0;
        if (sb.st_mode & S_IFREG)
            DEBUG(1, ("[!] '%s' is a file instead of a folder!\n", path));
            return -1;
    } else {
        if (errno = ENOENT) {
            DEBUG(5, ("[+] The directory %s does not exist. Creating it...\n",
                      path));
            retval = mkdir(path, S_IRWXU);
            if (retval != 0) {
                DEBUG(1, ("[!] Unable to create directory '%s'; errno = %d!\n",
                          path, errno));
                return -1;
            }
        } else {
            DEBUG(1, ("[!] Unable to create directory '%s'; errno = %d!\n",
                      path, errno));
            return -1;
        }
    }
    return 0;
}

static enum MAPISTATUS export_mailbox(TALLOC_CTX *mem_ctx,
                                      mapi_object_t *obj_store,
                                      struct mailboxdata *mdata,
                                      amqp_connection_state_t conn)
{
    enum MAPISTATUS       retval;
    int                   ret;
    mapi_id_t             id_mailbox;
    const char           *mailbox_name;

    ret = create_directory(DEFAULT_EXPORT_PATH);
    if (ret != 0) {
        return MAPI_E_UNABLE_TO_COMPLETE;
    }

    return recursive_mailbox_export(
        mem_ctx, obj_store, obj_store, mdata->TreeRoot , mdata, conn);
}
#endif

static void mbox_estimate_summary(struct mbox_data *mdata)
{
    DEBUG(0, ("[+]-------------- Mailbox Summary (%s) ----------------------------------\n", mdata->username));
    DEBUG(0, ("\t* Mailbox size %"PRId64" kilobytes\n", mdata->MailboxSize/1024));
    DEBUG(0, ("\t* Total number of folders: %d\n", mdata->FolderCount));
    DEBUG(0, ("\t* Total number of items: %d\n", mdata->items.total));
    DEBUG(0, ("\t\t* Emails:              %d\n", mdata->items.mail));
    DEBUG(0, ("\t\t* Appointments:        %d\n", mdata->items.appointment));
    DEBUG(0, ("\t\t* Contacts:            %d\n", mdata->items.contact));
    DEBUG(0, ("\t\t* Tasks:               %d\n", mdata->items.task));
    DEBUG(0, ("\t\t* StickyNote:          %d\n", mdata->items.stickynote));
    DEBUG(0, ("\t\t* Journal:             %d\n", mdata->items.journal));
    DEBUG(0, ("\t* Total number of attachments:\n"));
    DEBUG(0, ("\t\t* Total number:        %d\n", mdata->items.attachments));
    DEBUG(0, ("\t\t* Total size:          %d kilobytes\n", mdata->items.attachmentSize/1024));
    DEBUG(0, ("[+]-----------------------------------------------------------------\n"));
}

static enum MAPISTATUS mbox_estimate_attachments(
        TALLOC_CTX *mem_ctx,
        mapi_object_t *obj_store,
        mapi_object_t *obj_folder,
        struct mbox_data *mdata)
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
                        //send_calculation(conn, mdata, mem_ctx);

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


static enum MAPISTATUS mbox_estimate_items(
        TALLOC_CTX *mem_ctx,
        uint32_t contentcount,
        const char *containerclass,
        struct mbox_data *mdata)
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
    //send_calculation(conn, mdata, mem_ctx);

    return MAPI_E_SUCCESS;
}

static void mbox_estimate_recurse(
        TALLOC_CTX *mem_ctx,
        mapi_object_t *obj_store,
        mapi_object_t *parent,
        struct mbox_tree_item *folder,
        struct mbox_data *mdata)
{
    enum MAPISTATUS     retval = MAPI_E_SUCCESS;
    mapi_object_t       obj_folder;
    mapi_object_t       obj_table;
    struct SPropTagArray    *SPropTagArray;
    struct SRowSet      rowset;
    struct SRow     aRow;
    uint32_t        index;
    const char      *containerclass;
    const uint32_t      *messagesize;
    const uint32_t      *child;
    const uint32_t      *contentcount;
    uint32_t        count;
    struct mbox_tree_item *element;

    mapi_object_init(&obj_folder);
    retval = OpenFolder(parent, folder->id, &obj_folder);
    if (retval) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] OpenFolder: %s\n", error));
        // TODO Add error to user data
        mapi_object_release(&obj_folder);
        return;
    }

    mapi_object_init(&obj_table);
    retval = GetHierarchyTable(&obj_folder, &obj_table, 0, &count);
    if (retval) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] OpenFolder: %s\n", error));
        // TODO Add error to user data
        mapi_object_release(&obj_table);
        mapi_object_release(&obj_folder);
        return;
    }
    mdata->FolderCount += count;
//    send_calculation(conn, mdata, mem_ctx);

    SPropTagArray = set_SPropTagArray(mem_ctx, 0x6,
                      PidTagDisplayName,
                      PidTagFolderId,
                      PidTagMessageSize,
                      PidTagFolderChildCount,
                      PidTagContainerClass,
                      PidTagContentCount);
    retval = SetColumns(&obj_table, SPropTagArray);
    MAPIFreeBuffer(SPropTagArray);
    if (retval) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] SetColumns: %s\n", error));
        // TODO Add error to user data
        mapi_object_release(&obj_table);
        mapi_object_release(&obj_folder);
    }

    folder->children = talloc_zero(mem_ctx, struct mbox_tree_item);
    while (((retval = QueryRows(&obj_table, 0x32, TBL_ADVANCE, &rowset)) != MAPI_E_NOT_FOUND) && rowset.cRows) {
        for (index = 0; index < rowset.cRows; index++) {
            element = talloc_zero(mem_ctx, struct mbox_tree_item);
            DLIST_ADD(folder->children, element);

            aRow = rowset.aRow[index];
            element->id = *(const uint64_t *) find_SPropValue_data(&aRow, PidTagFolderId);
            element->name = talloc_strdup(mem_ctx, find_SPropValue_data(&aRow, PidTagDisplayName));
            element->path = talloc_asprintf(mem_ctx, "%s/%s", folder->path, element->name);
            element->parent = folder;
            child = (const uint32_t *) find_SPropValue_data(&aRow, PidTagFolderChildCount);
            messagesize = (const uint32_t *) find_SPropValue_data(&aRow, PidTagMessageSize);
            containerclass = (const char *) find_SPropValue_data(&aRow, PidTagContainerClass);
            contentcount = (const uint32_t *) find_SPropValue_data(&aRow, PidTagContentCount);

            if (messagesize) {
                mdata->MailboxSize += *messagesize;
                //send_calculation(conn, mdata, mem_ctx);
            } else {
                DEBUG(1, ("[!] PidTagMessageSize unavailable for folder %s\n",
                          element->name ? element->name : ""));
                //goto end;
            }

            DEBUG(3, ("[+][folder][name=\"%s\"][size=%d][children=%s][class=%s][count=%d]\n",
                      element->name ? element->name:"",
                      messagesize?*messagesize:-1, child?"yes":"no",
                      containerclass?containerclass:"unknown",
                      contentcount?*contentcount:0));

            if (child && *child) {
                mbox_estimate_recurse(mem_ctx, obj_store, &obj_folder, element, mdata);
            }

            /* Attachment count */
            if ((!containerclass || (containerclass && !strcmp(containerclass, "IPF.Note"))) &&
                (contentcount && *contentcount != 0)) {
                retval = mbox_estimate_attachments(mem_ctx, obj_store, &obj_folder, mdata);
                if (retval)
                    goto end;
            }

            /* Item counters */
            retval = mbox_estimate_items(mem_ctx, *contentcount, containerclass, mdata);
            if (retval)
                goto end;
        }
    }

end:
    mapi_object_release(&obj_table);
    mapi_object_release(&obj_folder);
}


static void mbox_estimate(struct status *status, struct mbox_data *data)
{
    enum MAPISTATUS retval;
    mapi_object_t obj_store;
    struct SPropTagArray *SPropTagArray;
    struct SPropValue    *lpProps;
    uint32_t              cValues;
    struct mbox_tree_item *element;

    DEBUG(0, ("[*] Estimating user %s\n", data->username));

    mapi_object_init(&obj_store);

    /* Open Default Message Store */
    retval = OpenUserMailbox(status->session, data->username, &obj_store);
    if (retval != MAPI_E_SUCCESS) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] OpenUserMailbox: %s\n", error));
        // TODO Add error to user data
        mapi_object_release(&obj_store);
        return;
    }

    /* Calculation task and print */
    element = talloc_zero(data, struct mbox_tree_item);

    /* Prepare the recursive directory listing */
    retval = GetDefaultFolder(&obj_store, &element->id, olFolderTopInformationStore);
    if (retval != MAPI_E_SUCCESS) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] GetDefaultFolder: %s\n", error));
        // TODO Add error to user data
        mapi_object_release(&obj_store);
        return;
    }

    /* Retrieve the mailbox folder name */
    SPropTagArray = set_SPropTagArray(data, 0x1, PR_DISPLAY_NAME_UNICODE);
    retval = GetProps(&obj_store, MAPI_UNICODE, SPropTagArray, &lpProps, &cValues);
    MAPIFreeBuffer(SPropTagArray);
    if (retval != MAPI_E_SUCCESS) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] GetProps: %s\n", error));
        // TODO Add error to user data
        mapi_object_release(&obj_store);
        return;
    }

    if (lpProps[0].value.lpszW) {
        element->name = talloc_strdup(data, lpProps[0].value.lpszW);
    } else {
        talloc_free(element);
        DEBUG(0, ("[!] GetProps: No value\n"));
        // TODO Add error to user data
        mapi_object_release(&obj_store);
        return;
    }
    element->path = talloc_asprintf(data, "%s/%s", DEFAULT_EXPORT_PATH,
                                    element->name);
    data->tree_root = talloc_zero(data, struct mbox_tree_item);
    DLIST_ADD(data->tree_root, element);

    mbox_estimate_recurse(data, &obj_store, &obj_store, element, data);

    mapi_object_release(&obj_store);
}

void* mbox_start_estimate_thread(void *arg)
{
    struct status *status = (struct status *)arg;
    int i;

    DEBUG(0, ("[*] Estimating thread started\n"));
    status->state = STATE_ESTIMATING;
    for (i=0; i<array_list_length(status->mbox_list); i++) {
        struct mbox_data *data =
            (struct mbox_data *) array_list_get_idx(status->mbox_list, i);
        mbox_estimate(status, data);
        mbox_estimate_summary(data);
    }
    status->state = STATE_ESTIMATED;
    DEBUG(0, ("[*] Estimating thread stopped\n"));
    return NULL;
}

void mbox_data_free(void *data)
{
    talloc_free(data);
}

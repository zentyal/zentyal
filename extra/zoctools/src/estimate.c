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

static void estimate_mbox_summary(struct mbox_data *mdata)
{
    DEBUG(0, ("[+]-------------- Mailbox Summary (%s) ----------------------------------\n", mdata->username));
    DEBUG(0, ("\t* Mailbox size %"PRId64" bytes\n", mdata->counters.total_bytes));
    DEBUG(0, ("\t* Total number of folders: %lu\n", mdata->counters.total_folders));
    DEBUG(0, ("\t* Total number of items: %lu\n", mdata->counters.total_items));
    DEBUG(0, ("\t* Total number of attachments:\n"));
    DEBUG(0, ("\t\t* Email items:         %lu\n", mdata->counters.email_items));
    DEBUG(0, ("\t\t* Email bytes:         %lu\n", mdata->counters.email_bytes));
    DEBUG(0, ("\t\t* Appointment items:   %lu\n", mdata->counters.appointment_items));
    DEBUG(0, ("\t\t* Appointment bytes:   %lu\n", mdata->counters.appointment_bytes));
    DEBUG(0, ("\t\t* Contact items:       %lu\n", mdata->counters.contact_items));
    DEBUG(0, ("\t\t* Contact bytes:       %lu\n", mdata->counters.contact_bytes));
    DEBUG(0, ("\t\t* Task items:          %lu\n", mdata->counters.task_items));
    DEBUG(0, ("\t\t* Task bytes:          %lu\n", mdata->counters.task_bytes));
    DEBUG(0, ("\t\t* Note items:          %lu\n", mdata->counters.note_items));
    DEBUG(0, ("\t\t* Note bytes:          %lu\n", mdata->counters.note_bytes));
    DEBUG(0, ("\t\t* Journal:             %lu\n", mdata->counters.journal_items));
    DEBUG(0, ("\t\t* Attachment items:    %lu\n", mdata->counters.attachment_items));
    DEBUG(0, ("\t\t* Attachment bytes:    %lu bytes\n", mdata->counters.attachment_bytes));
    DEBUG(0, ("[+]-----------------------------------------------------------------\n"));
}

static void estimate_update_counters(struct mbox_data *mdata,
                const char *containerclass,
                uint32_t size)
{
    int contentcount = 1;
    //if (contentcount == 0) return MAPI_E_SUCCESS;

    mdata->counters.total_items += contentcount;
    mdata->counters.total_bytes += size;

    if (containerclass) {
        if (!strncmp(containerclass, "IPF.Note", strlen(containerclass))) {
            mdata->counters.email_items += contentcount;
            mdata->counters.email_bytes += size;
        } else if (!strncmp(containerclass, "IPF.StickyNote", strlen(containerclass))) {
            mdata->counters.note_items += contentcount;
            mdata->counters.note_bytes += size;
        } else if (!strncmp(containerclass, "IPF.Appointment", strlen(containerclass))) {
            mdata->counters.appointment_items += contentcount;
            mdata->counters.appointment_bytes += size;
        } else if (!strncmp(containerclass, "IPF.Contact", strlen(containerclass))) {
            mdata->counters.contact_items += contentcount;
            mdata->counters.contact_bytes += size;
        } else if (!strncmp(containerclass, "IPF.Task", strlen(containerclass))) {
            mdata->counters.task_items += contentcount;
            mdata->counters.task_bytes += size;
        } else if (!strncmp(containerclass, "IPF.Journal", strlen(containerclass))) {
            mdata->counters.journal_items += contentcount;
            mdata->counters.journal_bytes += size;
        }
    } else {
        /* undefined items are always mail by default */
        //mdata->counters.email_items += contentcount;
        //mdata->counters.email_bytes += size;
    }
}


static enum MAPISTATUS estimate_folder_content(TALLOC_CTX *mem_ctx,
                     mapi_object_t *obj_store,
                     mapi_object_t *obj_folder,
                     struct mbox_data *mdata)
{
    enum MAPISTATUS     retval = MAPI_E_SUCCESS;
    mapi_object_t       obj_ctable;
    mapi_object_t       obj_atable;
    mapi_object_t       obj_msg;
    struct SPropTagArray    *SPropTagArray;
    struct SPropValue       *lpProp;
    struct SRowSet      rowset;
    struct SRow     aRow;
    struct SRowSet      arowset;
    const uint8_t       *has_attach;
    const uint64_t      *fid;
    const uint64_t      *msgid;
    const uint32_t      *size;
    const char      *filename;
    uint32_t        *attachmentsize;
    uint32_t        index;
    uint32_t        aindex;
    const char      *class;
    uint32_t        count;

    mapi_object_init(&obj_ctable);

    /* Get container class */
    SPropTagArray = set_SPropTagArray(mem_ctx, 0x1, PR_CONTAINER_CLASS);
    retval = GetProps(obj_folder, MAPI_UNICODE, SPropTagArray, &lpProp, &count);
    MAPIFreeBuffer(SPropTagArray);
    if ((lpProp[0].ulPropTag != PR_CONTAINER_CLASS) || (retval != MAPI_E_SUCCESS)) {
            class = IPF_NOTE;
    } else {
        class = lpProp[0].value.lpszA;
    }
    printf("class %s\n",class);

    /* Get folder content */
    retval = GetContentsTable(obj_folder, &obj_ctable, 0, &count);
    MAPI_RETVAL_IF(retval, retval, NULL);

    SPropTagArray = set_SPropTagArray(mem_ctx, 0x4,
                      PidTagFolderId,
                      PidTagMid,
                      PR_MESSAGE_SIZE,
                      PidTagHasAttachments);
    retval = SetColumns(&obj_ctable, SPropTagArray);
    if (retval) {
        mapi_object_release(&obj_ctable);
        MAPIFreeBuffer(SPropTagArray);
        return retval;
    }
    MAPIFreeBuffer(SPropTagArray);

    while (((retval = QueryRows(&obj_ctable, count, TBL_ADVANCE, &rowset)) != MAPI_E_NOT_FOUND)
           && rowset.cRows) {
        count -= rowset.cRows;
        for (index = 0; index < rowset.cRows; index++) {
            aRow = rowset.aRow[index];
            fid = (const uint64_t *) find_SPropValue_data(&aRow, PidTagFolderId);
            msgid = (const uint64_t *) find_SPropValue_data(&aRow, PidTagMid);
            size = (const uint32_t *) find_SPropValue_data(&aRow, PR_MESSAGE_SIZE);
            has_attach = (const uint8_t *) find_SPropValue_data(&aRow, PidTagHasAttachments);

            DEBUG(4, ("[+][item][mid=%"PRIx64"][size=%u][attachments=%s]\n", *msgid, *size, (*has_attach==true)?"yes":"no"));

            estimate_update_counters(mdata, class, *size);

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
                        mdata->counters.attachment_bytes += *attachmentsize;
                        mdata->counters.attachment_items += 1;
                        mdata->counters.total_items += 1;
                        mdata->counters.total_bytes += *attachmentsize;
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


static void estimate_mbox_recurse(TALLOC_CTX *mem_ctx,
                  mapi_object_t *obj_store,
                  mapi_object_t *parent,
                  struct mbox_tree_item *folder,
                  struct mbox_data *mdata)
{
    enum MAPISTATUS     retval = MAPI_E_SUCCESS;
    struct mbox_tree_item   *element;
    mapi_object_t       obj_folder;
    mapi_object_t       obj_table;
    struct SPropTagArray    *SPropTagArray;
    struct SRowSet      rowset;
    struct SRow     aRow;
    uint32_t        index;
    uint32_t        count;
    const uint32_t      *messagesize;
    const uint32_t      *child;
    const uint32_t      *contentcount;
    const char      *containerclass;
    const char      *error;

    mapi_object_init(&obj_folder);
    DEBUG(4, ("[*] Opening folder %"PRIx64"\n", folder->id));
    retval = OpenFolder(parent, folder->id, &obj_folder);
    if (retval) {
        error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] OpenFolder: %s\n", error));
        // TODO Add error to user data
        mapi_object_release(&obj_folder);
        return;
    }

    retval = estimate_folder_content(mem_ctx, obj_store, &obj_folder, mdata);

    mapi_object_init(&obj_table);
    retval = GetHierarchyTable(&obj_folder, &obj_table, 0, &count);
    if (retval) {
        error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] OpenFolder: %s\n", error));
        // TODO Add error to user data
        mapi_object_release(&obj_table);
        mapi_object_release(&obj_folder);
        return;
    }
    mdata->counters.total_folders += count;

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
        error = mapi_get_errstr(GetLastError());
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
            element->parent = folder;
            child = (const uint32_t *) find_SPropValue_data(&aRow, PidTagFolderChildCount);
            messagesize = (const uint32_t *) find_SPropValue_data(&aRow, PidTagMessageSize);
            containerclass = (const char *) find_SPropValue_data(&aRow, PidTagContainerClass);
            contentcount = (const uint32_t *) find_SPropValue_data(&aRow, PidTagContentCount);

            DEBUG(3, ("[+][folder][id=\"0x%"PRIx64"][size=%d][children=%s][class=%s][count=%d]\n",
                  element->id,
                  messagesize ? *messagesize : 0,
                  child ? "yes" : "no",
                  containerclass?containerclass:"unknown",
                  contentcount?*contentcount:0));

            estimate_mbox_recurse(mem_ctx, obj_store, &obj_folder, element, mdata);
        }
    }

    mapi_object_release(&obj_table);
    mapi_object_release(&obj_folder);
}


static void estimate_mbox(struct status *status, struct mbox_data *data)
{
    enum MAPISTATUS     retval;
    mapi_object_t       obj_store;
    struct mbox_tree_item   *element;
    const char      *error;

    DEBUG(0, ("[*] Estimating user %s\n", data->username));
    data->start_time = time(NULL);

    mapi_object_init(&obj_store);

    /* Open Default Message Store */
    retval = OpenUserMailbox(status->remote.session, data->username, &obj_store);
    if (retval != MAPI_E_SUCCESS) {
        error = mapi_get_errstr(GetLastError());
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
        error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] GetDefaultFolder: %s\n", error));
        // TODO Add error to user data
        mapi_object_release(&obj_store);
        return;
    }

    data->tree_root = talloc_zero(data, struct mbox_tree_item);
    DLIST_ADD(data->tree_root, element);

    estimate_mbox_recurse(data, &obj_store, &obj_store, element, data);

    mapi_object_release(&obj_store);
    data->end_time = time(NULL);
}


void *estimate_start_thread(void *arg)
{
    struct status       *status;
        struct mbox_data    *mdata;
    int         i;

    status = (struct status *)arg;

    DEBUG(1, ("[*] Estimating thread started\n"));
    status->state = STATE_ESTIMATING;
    status->start_time = time(NULL);
    for (i = 0; i < array_list_length(status->mbox_list); i++) {
        mdata = (struct mbox_data *) array_list_get_idx(status->mbox_list, i);
        estimate_mbox(status, mdata);
        estimate_mbox_summary(mdata);
    }
    status->state = STATE_ESTIMATED;
    status->end_time = time(NULL);
    DEBUG(1, ("[*] Estimating thread stopped\n"));
    return NULL;
}


void estimate_data_free(void *mdata)
{
    talloc_free(mdata);
}

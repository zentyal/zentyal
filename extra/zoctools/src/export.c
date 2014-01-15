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

#include <stdbool.h>
#include <inttypes.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <json/arraylist.h>
#include <tdb.h>
#include <libocpf/ocpf.h>
#include <libmapi/libmapi.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>

#include "migrate.h"

static void export_update_counters(struct mbox_data *mdata,
                   const char *containerclass,
                   uint32_t size)
{
    mdata->counters.exported_total_items += 1;
    mdata->counters.exported_total_bytes += size;

    if (containerclass) {
        if (!strncmp(containerclass, "IPF.Note", strlen(containerclass))) {
            mdata->counters.exported_email_items += 1;
            mdata->counters.exported_email_bytes += size;
        } else if (!strncmp(containerclass, "IPF.StickyNote", strlen(containerclass))) {
            mdata->counters.exported_note_items += 1;
            mdata->counters.exported_note_bytes += size;
        } else if (!strncmp(containerclass, "IPF.Appointment", strlen(containerclass))) {
            mdata->counters.exported_appointment_items += 1;
            mdata->counters.exported_appointment_bytes += size;
        } else if (!strncmp(containerclass, "IPF.Contact", strlen(containerclass))) {
            mdata->counters.exported_contact_items += 1;
            mdata->counters.exported_contact_bytes += size;
        } else if (!strncmp(containerclass, "IPF.Task", strlen(containerclass))) {
            mdata->counters.exported_task_items += 1;
            mdata->counters.exported_task_bytes += size;
        } else if (!strncmp(containerclass, "IPF.Journal", strlen(containerclass))) {
            mdata->counters.exported_journal_items += 1;
            mdata->counters.exported_journal_bytes += size;
        }
    } else {
        /* undefined items are always mail by default */
        mdata->counters.exported_email_items += 1;
        mdata->counters.exported_email_bytes += size;
    }

    return;
}

static int export_create_directory(TALLOC_CTX *mem_ctx, const char *path)
{
    int     retval;
    struct stat sb;
    time_t t;
    struct tm *local_time;
    char datestr[200];
    char *backup_path;

    DEBUG(5, ("[+] Creating the export directory %s\n", path));
    retval = stat(path, &sb);
    if (retval == 0) {
        if (sb.st_mode & S_IFDIR) {
            DEBUG(5, ("[+] Already exists, moving as a backup folder...\n"));
            t = time(NULL);
            local_time = localtime(&t);
            if (local_time == NULL) {
                DEBUG(0, ("[!] Unable to clean previous export!"));
                return -1;
            }

            if (strftime(datestr, sizeof(datestr), "%Y%m%d%H%M%S", local_time) == 0) {
                DEBUG(0, ("[!] Unable to clean previous export!"));
                return -1;
            }
            backup_path = talloc_asprintf(mem_ctx, "%s-%s", path, datestr);
            if (rename(path, backup_path)) {
                talloc_free(backup_path);
                backup_path = NULL;
                DEBUG(0, ("[!] Unable to clean previous export!"));
                return -1;
            }
            talloc_free(backup_path);
            retval = stat(path, &sb);
            if (retval == 0) {
                DEBUG(0, ("[!] Unable to clean previous export!"));
                return -1;
            }
        } else if (sb.st_mode & S_IFREG) {
            DEBUG(0, ("[!] '%s' is a file instead of a folder!\n", path));
            return -1;
        }
    }

    if (errno == ENOENT) {
        DEBUG(5, ("[+] The directory '%s' does not exist. Creating it...\n", path));
        retval = mkdir(path, S_IRWXU);
        if (retval != 0) {
            DEBUG(1, ("[!] Unable to create directory '%s'; errno = %d (%s)\n",
                  path, errno, strerror(errno)));
            return -1;
        }
        return 0;
    }

    DEBUG(0, ("[!] Unable to create directory 2 '%s'; errno = %d (%s)\n",
          path, errno, strerror(errno)));
    return -1;
}


static bool messages_dump(TALLOC_CTX *mem_ctx,
              mapi_object_t *obj_store,
              mapi_object_t *parent,
              struct mbox_tree_item *folder,
              struct mbox_data *mdata,
              const char *base_path)
{
    enum MAPISTATUS         retval;
    int             ret;
    mapi_object_t           obj_folder;
    mapi_object_t           obj_message;
    char                *filename = NULL;
    struct mapi_SPropValue_array    lpProps;
    uint32_t            context_id;
    mapi_object_t           obj_htable;
    struct SPropTagArray        *SPropTagArray;
    struct SRowSet          SRowSet;
    uint32_t            i;
    uint32_t            count;
    const uint64_t          *fid;
    const uint64_t          *mid;
    const uint32_t          *size;
    const char          *class;
    struct SPropValue           *lpProp;

    /* Search the folder from Top Information Store */
    mapi_object_init(&obj_folder);
    retval = OpenFolder(parent, folder->id, &obj_folder);
    if (retval != MAPI_E_SUCCESS) return false;

    /* Get container class */
    SPropTagArray = set_SPropTagArray(mem_ctx, 0x1, PR_CONTAINER_CLASS);
    retval = GetProps(&obj_folder, MAPI_UNICODE, SPropTagArray, &lpProp, &count);
    MAPIFreeBuffer(SPropTagArray);
    if ((lpProp[0].ulPropTag != PR_CONTAINER_CLASS) || (retval != MAPI_E_SUCCESS)) {
            class = IPF_NOTE;
    } else {
        class = lpProp[0].value.lpszA;
    }

    /* Search the messages */
    mapi_object_init(&obj_htable);
    retval = GetContentsTable(&obj_folder, &obj_htable, 0, &count);
    if (retval != MAPI_E_SUCCESS) {
        mapi_object_release(&obj_folder);
        return false;
    }

    DEBUG(4, ("Exporting folder 0x%"PRIx64", %d messages\n", folder->id, count));
    if (!count) {
        mapi_object_release(&obj_htable);
        mapi_object_release(&obj_folder);
        return true;
    }

    SPropTagArray = set_SPropTagArray(mem_ctx, 0x3,
                                        PR_FID,
                                        PR_MID,
                    PR_MESSAGE_SIZE);
    retval = SetColumns(&obj_htable, SPropTagArray);
    MAPIFreeBuffer(SPropTagArray);
    if (retval != MAPI_E_SUCCESS) {
        mapi_object_release(&obj_htable);
        mapi_object_release(&obj_folder);
        return false;
    }

    while (((retval = QueryRows(&obj_htable, count, TBL_ADVANCE, &SRowSet)) != MAPI_E_NOT_FOUND) && SRowSet.cRows) {
        count -= SRowSet.cRows;
        for (i = 0; i < SRowSet.cRows; i++) {
            bool ocpf_initialized = false;
            if (ocpf_init() != OCPF_SUCCESS) {
                DEBUG(0, ("[!] ocpf_init\n"));
                continue;
            }
            ocpf_initialized = true;

            mapi_object_init(&obj_message);
            fid = (const uint64_t *)find_SPropValue_data(&SRowSet.aRow[i], PR_FID);
            mid = (const uint64_t *)find_SPropValue_data(&SRowSet.aRow[i], PR_MID);
            size = (const uint32_t *)find_SPropValue_data(&SRowSet.aRow[i], PR_MESSAGE_SIZE);
            retval = OpenMessage(&obj_folder, *fid, *mid, &obj_message, ReadWrite);
            if (retval != MAPI_E_SUCCESS) {
                if (ocpf_initialized) {
                    ocpf_release();
                }
                mapi_object_release(&obj_message);
                mapi_object_release(&obj_htable);
                mapi_object_release(&obj_folder);
                DEBUG(0, ("[!] OpenMessage: %s\n", mapi_get_errstr(retval)));
                continue;
            }
            /* Step 3. retrieve all message properties */
            retval = GetPropsAll(&obj_message, MAPI_UNICODE, &lpProps);
            if (retval != MAPI_E_SUCCESS) {
                if (ocpf_initialized) {
                    ocpf_release();
                }
                mapi_object_release(&obj_message);
                mapi_object_release(&obj_htable);
                mapi_object_release(&obj_folder);
                DEBUG(0, ("[!] GetPropsAll: %s\n", mapi_get_errstr(retval)));
                continue;
            }

            /* Step 4. save the message */
            filename = talloc_asprintf(mem_ctx, "%s/0x%" PRIx64 ".ocpf", base_path, *mid);

            DEBUG(5, ("OCPF output file: %s\n", filename));

            ret = ocpf_new_context(filename, &context_id, OCPF_FLAGS_CREATE);
            if (ret != OCPF_SUCCESS) {
                if (ocpf_initialized) {
                    ocpf_release();
                }
                mapi_object_release(&obj_message);
                mapi_object_release(&obj_htable);
                mapi_object_release(&obj_folder);
                DEBUG(0, ("[!] ocpf_new_context\n"));
                continue;
            }

            talloc_free(filename);
            ret = ocpf_write_init(context_id, folder->id);
            if (ret != OCPF_SUCCESS) {
                if (ocpf_initialized) {
                    ocpf_release();
                }
                mapi_object_release(&obj_message);
                mapi_object_release(&obj_htable);
                mapi_object_release(&obj_folder);
                DEBUG(0, ("[!] ocpf_write_init\n"));
                continue;
            }

            ret = ocpf_write_auto(context_id, &obj_message, &lpProps);
            if (ret == OCPF_SUCCESS) {
                ret = ocpf_write_commit(context_id);
            }

            ret = ocpf_del_context(context_id);
            if (ocpf_initialized) {
                ocpf_release();
            }

            export_update_counters(mdata, class, *size);

            mapi_object_release(&obj_message);
        }
    }

    mapi_object_release(&obj_htable);
    mapi_object_release(&obj_folder);

    return true;
}


static enum MAPISTATUS export_mbox_recursive(TALLOC_CTX *mem_ctx,
                         mapi_object_t *obj_store,
                         mapi_object_t *parent,
                         struct mbox_tree_item *folder,
                         struct mbox_data *mdata,
                         const char *base_path)
{
    enum MAPISTATUS     retval = MAPI_E_SUCCESS;
    mapi_object_t       obj_folder;
    int         ret;
    struct mbox_tree_item   *element;
    struct SPropTagArray    *SPropTagArray;
    struct SPropValue   *lpProps;
    struct SRow     aRow;
    uint32_t        cValues;
    TDB_DATA        tkey;
    TDB_DATA        tval;
    char            *path;
    const char      *folder_name;
    uint32_t        olFolder;

    mapi_object_init(&obj_folder);
    retval = OpenFolder(parent, folder->id, &obj_folder);
    MAPI_RETVAL_IF(retval, retval, NULL);

    path = talloc_asprintf(mdata, "%s/0x%"PRIx64, base_path, folder->id);
    /* Check if folder is system folder */
    if ((IsMailboxFolder(obj_store, folder->id, &olFolder) == true) &&
        (olFolder == olFolderCalendar || olFolder == olFolderContacts ||
         olFolder == olFolderTopInformationStore)) {
        /* TODO: Support more folder types. */
         tkey.dptr = (unsigned char *)talloc_asprintf(mem_ctx, "0x%"PRIx64, folder->id);
        tkey.dsize = strlen((char *)tkey.dptr);
        tval.dptr = (unsigned char *)talloc_asprintf(mem_ctx, "%d", olFolder);
        tval.dsize = strlen((char *)tval.dptr);
        ret = tdb_store(mdata->tdb_sysfolder, tkey, tval, TDB_INSERT);
        talloc_free(tkey.dptr);
        talloc_free(tval.dptr);

        mdata->counters.exported_total_folders++;

        ret = export_create_directory(mdata, path);
        if (ret == -1) {
            retval = MAPI_E_UNABLE_TO_COMPLETE;
            goto end;
        }

        SPropTagArray = set_SPropTagArray(mem_ctx, 0x1, PidTagDisplayName);
        retval = GetProps(&obj_folder, MAPI_UNICODE, SPropTagArray, &lpProps, &cValues);
        MAPIFreeBuffer(SPropTagArray);
        if (retval != MAPI_E_SUCCESS) {
            goto end;
        }

        aRow.cValues = cValues;
        aRow.lpProps = lpProps;
        folder_name = find_SPropValue_data(&aRow, PidTagDisplayName);
        if (!folder_name) {
            retval = MAPI_E_NOT_FOUND;
            goto end;
        }

        tkey.dptr = (unsigned char *)talloc_asprintf(mem_ctx, "0x%"PRIx64, folder->id);
        tkey.dsize = strlen((char *) tkey.dptr);
        tval.dptr = (unsigned char *)folder_name;
        tval.dsize = strlen((char *)tval.dptr);

        ret = tdb_store(mdata->tdb_foldermap, tkey, tval, TDB_INSERT);
        talloc_free(tkey.dptr);

        messages_dump(mem_ctx, obj_store, parent, folder, mdata, path);
    }

    for (element = folder->children; element && element->next; element = element->next) {
        retval = export_mbox_recursive(mem_ctx, obj_store, &obj_folder, element, mdata, path);
        if (retval) {
            DEBUG(0, ("export_mbox_recursive: %s\n", mapi_get_errstr(retval)));
            goto end;
        }
    }

end:
    mapi_object_release(&obj_folder);
    if (path) {
        talloc_free(path);
    }
    return retval;
}

static struct tdb_context *tdb_open_database(TALLOC_CTX *mem_ctx,
                         char *base_path,
                         char *dbname)
{
    struct tdb_context  *tdb_ctx;
    int         db_flags;
    int         open_flags;
    mode_t          open_mode;
    char            *db_name;

    db_flags = TDB_CLEAR_IF_FIRST;
    open_flags = O_CREAT | O_TRUNC | O_RDWR;
    open_mode = 0600;
    db_name = talloc_asprintf(mem_ctx, "%s/%s", base_path, dbname);
    if (!dbname) return NULL;

    tdb_ctx = tdb_open(db_name, 0, db_flags, open_flags, open_mode);
    if (!tdb_ctx) {
        DEBUG(0, ("[!] Unable to open \"%s\" TDB database\n", dbname));
        talloc_free(db_name);
        return NULL;
    }

    talloc_free(db_name);
    return tdb_ctx;
}

static int export_mbox(TALLOC_CTX *mem_ctx,
               struct mapi_session *session,
               struct mbox_data *mdata)
{
    enum MAPISTATUS     retval;
    mapi_object_t       obj_store;
    const char      *error;
    char            *base_path;
    int         ret = 0;

    mdata->tdb_foldermap = NULL;
    mdata->tdb_sysfolder = NULL;
    mapi_object_init(&obj_store);

    retval = OpenUserMailbox(session, mdata->username, &obj_store);
    if (retval != MAPI_E_SUCCESS) {
        error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] OpenUserMailbox: %s\n", error));
        ret = -1;
        goto end;
    }

    base_path = talloc_asprintf(mdata, "%s/%s", DEFAULT_EXPORT_PATH, mdata->username);
    if (export_create_directory(mdata, base_path)) {
        ret = -1;
        goto end;
    }

    /* Create systemfolder database */
    mdata->tdb_sysfolder = tdb_open_database(mdata, base_path, TDB_SYSFOLDER);
    if (!mdata->tdb_sysfolder) {
        ret = -1;
        goto end;
    }

    /* Create PidTagFolderID to FolderName database */
    mdata->tdb_foldermap = tdb_open_database(mdata, base_path, TDB_FOLDERMAP);
    if (!mdata->tdb_foldermap) {
        ret = -1;
        goto end;
    }

    export_mbox_recursive(mem_ctx, &obj_store, &obj_store,
                  mdata->tree_root, mdata, base_path);

end:
    if (mdata->tdb_foldermap) {
        tdb_close(mdata->tdb_foldermap);
        mdata->tdb_foldermap = NULL;
    }
    if (mdata->tdb_sysfolder) {
        tdb_close(mdata->tdb_sysfolder);
        mdata->tdb_sysfolder = NULL;
    }
    mapi_object_release(&obj_store);
    if (base_path) {
        talloc_free(base_path);
        base_path = NULL;
    }

    return ret;
}

void *export_start_thread(void *arg)
{
    struct status       *status = (struct status *) arg;
    struct mbox_data    *data;
    int         i;
    int         ret;

    DEBUG(1, ("[*] Exporting thread started\n"));
    if (!status || !status->mbox_list) {
        goto fail;
    }

    status->state = STATE_EXPORTING;
    status->start_time = time(NULL);

    /* Create the base directory for exporting mailboxes */
    ret = export_create_directory(status->mem_ctx, DEFAULT_EXPORT_PATH);
    if (ret) {
        goto fail;
    }

    for (i = 0; i < array_list_length(status->mbox_list); i++) {
        data = (struct mbox_data *) array_list_get_idx(status->mbox_list, i);
        export_mbox(data, status->remote.session, data);
        // TODO export_mbox_summary(data);
    }

fail:
    status->state = STATE_EXPORTED;
    status->end_time = time(NULL);

    DEBUG(1, ("[*] Exporting thread stopped\n"));
    return NULL;
}

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

#include <stdlib.h>
#include <sys/types.h>
#include <dirent.h>
#include <tdb.h>
#include "migrate.h"

char *import_get_folder_id(const char *path)
{
    char    *id;

    id = strrchr(path, '/');
    if (id) {
        return id + 1;
    }
    return NULL;
}

char *import_get_folder_name(const struct mbox_data *mdata,
                 char *folder_id)
{
    TDB_DATA    value;
    TDB_DATA    key;
    char        *folderName;

    key.dptr = (unsigned char *)folder_id;
    key.dsize = strlen(folder_id);

    if (!tdb_exists(mdata->tdb_foldermap, key)) {
        return NULL;
    }
    value = tdb_fetch(mdata->tdb_foldermap, key);

    folderName = talloc_strndup(mdata, (char *)value.dptr, value.dsize);
    free(value.dptr);
    DEBUG(4, ("[*] Folder '%s' mapped to name '%s'\n", folder_id, folderName));
    return folderName;
}

char* import_is_system_folder(const struct mbox_data *mdata,
        char *folder_id)
{
    char *result;
    TDB_DATA value, key;
    key.dptr = (unsigned char *)folder_id;
    key.dsize = strlen(folder_id);

    if (!tdb_exists(mdata->tdb_sysfolder, key)) {
        return NULL;
    }
    value = tdb_fetch(mdata->tdb_sysfolder, key);
    result = talloc_strndup(mdata, (char *)value.dptr, value.dsize);
    free(value.dptr);

    DEBUG(5, ("[*] Folder '%s' is a system folder with id '%s'\n", folder_id, result));

    return result;
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

    db_flags = 0;
    open_flags = O_RDONLY;
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

static enum MAPISTATUS import_ocpf_file(TALLOC_CTX *mem_ctx,
                    const struct mbox_data *mdata,
                    mapi_object_t *obj_store,
                    mapi_object_t *obj_folder,
                    const char *base_path)
{
    int         ret;
    enum MAPISTATUS retval;
    mapi_object_t   obj_message;
    uint32_t    context_id;
    mapi_id_t   folder_id;
    uint32_t        cValues = 0;
    struct SPropValue *lpProps;

    DEBUG(4, ("[*] Importing OCPF file '%s'\n", base_path));

    /* Initialize OCPF context */
    ret = ocpf_init();
    if (ret == -1) {
        DEBUG(0, ("[!] ocpf_init\n"));
        return MAPI_E_CALL_FAILED;
    }

    folder_id =  mapi_object_get_id(obj_folder);
    if (folder_id == -1) {
        retval = MAPI_E_CALL_FAILED;
        DEBUG(0, ("[!] mapi_object_get_id: %s\n",
            mapi_get_errstr(retval)));
        return retval;
    }

    ret = ocpf_new_context(base_path, &context_id, OCPF_FLAGS_READ);
    if (ret == -1) {
        retval = MAPI_E_CALL_FAILED;
        DEBUG(0, ("[!] ocpf_new_context: %s\n", mapi_get_errstr(retval)));
        return retval;
    }

    ret = ocpf_parse(context_id);
    if (ret == -1) {
        retval = MAPI_E_CALL_FAILED;
        DEBUG(0, ("[!] ocpf_parse: %s\n", mapi_get_errstr(retval)));
        return retval;
    }

    /* Create the object */
    mapi_object_init(&obj_message);
    retval = CreateMessage(obj_folder, &obj_message);
    if (retval != MAPI_E_SUCCESS) {
        DEBUG(0, ("[!] CreateMessage: %s\n", mapi_get_errstr(retval)));
        mapi_object_release(&obj_message);
        return retval;
    }

    /* Set message recipients */
    //retval = ocpf_set_Recipients(mem_ctx, context_id, &obj_message);
    //if (retval != MAPI_E_SUCCESS && GetLastError() != MAPI_E_NOT_FOUND) return false;
    //errno = MAPI_E_SUCCESS;

    /* Set message properties */
    retval = ocpf_set_SPropValue(mem_ctx, context_id, obj_folder, &obj_message);
    if (retval == MAPI_W_ERRORS_RETURNED) {
        DEBUG(0, ("[!] ocpf_set_SPropValue: %s\n", mapi_get_errstr(retval)));
    } else if (retval != MAPI_E_SUCCESS) {
        DEBUG(0, ("[!] ocpf_set_SPropValue: %s\n", mapi_get_errstr(retval)));
        mapi_object_release(&obj_message);
        return retval;
    }

    /* Set message properties */
    lpProps = ocpf_get_SPropValue(context_id, &cValues);
    retval = SetProps(&obj_message, 0, lpProps, cValues);
    MAPIFreeBuffer(lpProps);
    if (retval != MAPI_E_SUCCESS) {
        DEBUG(0, ("[!] ocpf_get_SPropValue: %s\n", mapi_get_errstr(retval)));
        mapi_object_release(&obj_message);
        return retval;
    }

    retval = ocpf_server_set_folderID(context_id, folder_id);
    if (retval != MAPI_E_SUCCESS) {
        DEBUG(0, ("[!] ocpf_server_set_folderIF: %s\n", mapi_get_errstr(retval)));
        mapi_object_release(&obj_message);
        return retval;
    }

    /* Save message */
    retval = SaveChangesMessage(obj_folder, &obj_message, KeepOpenReadOnly);
    if (retval != MAPI_E_SUCCESS) {
        DEBUG(0, ("[!] SaveChangesMessage: %s\n", mapi_get_errstr(retval)));
        return retval;
    }

    mapi_object_release(&obj_message);
    ocpf_del_context(context_id);
    ocpf_release();
    return MAPI_E_SUCCESS;
}

static enum MAPISTATUS import_directory(TALLOC_CTX *mem_ctx,
                    const struct mbox_data *mdata,
                    mapi_object_t *obj_store,
                    mapi_object_t *obj_parent,
                    const char *base_path)
{
    enum MAPISTATUS retval;
    DIR     *dirp;
    struct dirent   *direntp;
    mapi_object_t   obj_folder;
    mapi_object_t   obj_inbox;
    mapi_object_t   obj_child;
    mapi_id_t   id_folder;
    char        *folder_id;
    char        *olFolderSrc;
    struct SPropTagArray        *SPropTagArray;
    struct SPropValue   *lpProps;
    uint32_t        cValues = 0;
    struct SRow          aRow;

    DEBUG(5,("[*] Importing directory %s\n", base_path));

    /* Open the filesystem folder */
    dirp = opendir(base_path);
    if (!dirp) {
        DEBUG(0, ("[!] Error opening directory %s: %s (%d)\n",
            base_path, strerror(errno), errno));
        return MAPI_E_NOT_FOUND; // TODO map to proper code
    }

    mapi_object_init(&obj_folder);
    mapi_object_init(&obj_child);
    mapi_object_init(&obj_inbox);

    /* I want to get the folder ID from the remote Exchange server and
    check in the systemfolder database if it matches with something.
    we can get the remote folder ID from the directory name */
    folder_id = import_get_folder_id(base_path);
    if (!folder_id) {
        DEBUG(0, ("[!] Error getting folder ID from directory name\n"));
        return MAPI_E_NOT_FOUND; // TODO map to proper code
    }

    if (!obj_parent) {
        DEBUG(5, ("parent is null\n"));

        retval = GetDefaultFolder(obj_store, &id_folder, olFolderInbox);
        if (retval != MAPI_E_SUCCESS) {
            DEBUG(0, ("[!] GetDefaultFolder: %s\n", mapi_get_errstr(GetLastError())));
            return retval;
        }
        DEBUG(4, ("[*] Opening folder %u\n", olFolderInbox));
        retval = OpenFolder(obj_store, id_folder, &obj_inbox);
        if (retval != MAPI_E_SUCCESS) {
            DEBUG(0, ("[!] OpenFolder: %s\n", mapi_get_errstr(GetLastError())));
            return retval;
        }
        obj_parent = &obj_inbox;
    }

    /* XXX Begin of hack */
#if 0
    olFolderSrc = import_is_system_folder(mdata, folder_id);
    if (!olFolderSrc) {
        DEBUG(5, ("[*] Not system folder, skip\n"));
        talloc_free(olFolderSrc);
        return MAPI_E_SUCCESS;
    }
    uint32_t olFolder = atoi(olFolderSrc);
    talloc_free(olFolderSrc);
    retval = MAPI_E_SUCCESS;
    if (olFolder == olFolderContacts) {
        retval = GetDefaultFolder(obj_store, &id_folder, olFolderContacts);
    } else if (olFolder == olFolderCalendar) {
        retval = GetDefaultFolder(obj_store, &id_folder, olFolderCalendar);
    } else if (olFolder == olFolderTopInformationStore) {
        retval = GetDefaultFolder(obj_store, &id_folder, olFolderInbox);
    }

    if (retval != MAPI_E_SUCCESS) {
        DEBUG(0, ("[!] GetDefaultFolder: %s\n", mapi_get_errstr(GetLastError())));
        return retval;
    }

    DEBUG(4, ("Opening folder %u\n", olFolder));
    retval = OpenFolder(obj_store, id_folder, &obj_folder);
    if (retval != MAPI_E_SUCCESS) {
        DEBUG(0, ("[!] OpenFolder: %s\n", mapi_get_errstr(GetLastError())));
        return retval;
    }
#endif
    /* XXX end of hack */
#if 1
    olFolderSrc = import_is_system_folder(mdata, folder_id);
    if (olFolderSrc) {
        char *folder_name = import_get_folder_name(mdata, folder_id);
        if (folder_name) {
            DEBUG(5, ("[*] Origin Folder '%s' mapped to name '%s'\n", folder_id, folder_name));
            talloc_free(folder_name);
            folder_name = NULL;
        }
        /* This is a system folder, then I am calling GetDefaultFolder
        to retrieve the id then I open the folder */
        uint32_t olFolder = atoi(olFolderSrc);
        talloc_free(olFolderSrc);

        retval = GetDefaultFolder(obj_store, &id_folder, olFolder);
        if (retval != MAPI_E_SUCCESS) {
            DEBUG(0, ("[!] GetDefaultFolder: %s\n", mapi_get_errstr(GetLastError())));
            return retval;
        }
        DEBUG(4, ("[*] Opening folder %u\n", olFolder));
        retval = OpenFolder(obj_store, id_folder, &obj_folder);
        if (retval != MAPI_E_SUCCESS) {
            DEBUG(0, ("[!] OpenFolder: %s\n", mapi_get_errstr(GetLastError())));
            return retval;
        }


        SPropTagArray = set_SPropTagArray(mem_ctx, 0x1, PidTagDisplayName);
        retval = GetProps(&obj_folder, MAPI_UNICODE, SPropTagArray, &lpProps, &cValues);
        MAPIFreeBuffer(SPropTagArray);
        if (retval == MAPI_E_SUCCESS) {
            aRow.cValues = cValues;
            aRow.lpProps = lpProps;
            folder_name = (char *) find_SPropValue_data(&aRow, PidTagDisplayName);
            if (folder_name) {
                DEBUG(5, ("[*] Destination Folder: '%s'\n", folder_name));
            }
        }
    } else {
        /*  this is not a system folder, I know what is the root base where
         need to create it i and open it */
        char *folder_name = import_get_folder_name(mdata, folder_id);
        if (!folder_name) {
            DEBUG(0, ("[!] Invalid Folder Name\n"));
            return MAPI_E_INVALID_PARAMETER;
        }
        DEBUG(4, ("[*] Creating folder %s\n", folder_name));
        retval = CreateFolder(obj_parent, FOLDER_GENERIC, folder_name,
                      NULL, OPEN_IF_EXISTS|MAPI_UNICODE, &obj_folder);
        if (retval != MAPI_E_SUCCESS) {
            DEBUG(0, ("[!] CreateFolder: %s\n", mapi_get_errstr(GetLastError())));
            talloc_free(folder_name);
            return retval;
        }
        talloc_free(folder_name);
        return MAPI_E_SUCCESS;
    }
#endif

    /* Import the files and clildren folders */
    while ((direntp = readdir(dirp)) != NULL) {
        if (strcmp(direntp->d_name, ".") == 0) {
            continue;
        }
        if (strcmp(direntp->d_name, "..") == 0) {
            continue;
        }
        char *ext = strrchr(direntp->d_name, '.');
        if (!ext) {
            if (strncasecmp(direntp->d_name, "0x", 2) == 0) {
                char *child_path = talloc_asprintf(mem_ctx, "%s/%s", base_path, direntp->d_name);
                retval = import_directory(mem_ctx, mdata, obj_store, &obj_folder, child_path);
                if (retval != MAPI_E_SUCCESS) {
                        DEBUG(0, ("import_directory failed with %s\n", mapi_get_errstr(GetLastError())));
                        talloc_free(child_path);
                        return retval;
                }
                talloc_free(child_path);
            }
            continue;
        }
        if (strncasecmp(ext, ".ocpf", 5) == 0) {
            char *child_path = talloc_asprintf(mem_ctx, "%s/%s", base_path, direntp->d_name);
            import_ocpf_file(mem_ctx, mdata, obj_store, &obj_folder, child_path);
            talloc_free(child_path);
        }
    }

    mapi_object_release(&obj_folder);
    mapi_object_release(&obj_inbox);

    /* Close directory */
    closedir(dirp);

    return retval;
}

void import_mailbox(TALLOC_CTX *mem_ctx,
               struct mapi_session *session,
               struct mbox_data *mdata)
{
    enum MAPISTATUS retval;
    struct dirent   *direntp;
    DIR     *dirp;
    mapi_object_t   obj_store;
    char        *base_path;

    mdata->start_time = time(NULL);

    base_path = talloc_asprintf(mem_ctx, "%s/%s", DEFAULT_EXPORT_PATH, mdata->username);
    if (!base_path) {
        goto fail;
    }


    /* Open systemfolder database */
    mdata->tdb_sysfolder = tdb_open_database(mdata, base_path, TDB_SYSFOLDER);
    if (!mdata->tdb_sysfolder) {
        DEBUG(0, ("[!] Error opening system folder db\n"));
        goto fail;
    }

    /* Open PidTagFolderID to FolderName database */
    mdata->tdb_foldermap = tdb_open_database(mdata, base_path, TDB_FOLDERMAP);
    if (!mdata->tdb_foldermap) {
        DEBUG(0, ("[!] Error opening id mapping db\n"));
        goto fail;
    }

    /* Open the folder */
    dirp = opendir(base_path);
    if (!dirp) {
        DEBUG(0, ("[!] Error opening directory %s: %s (%d)\n",
            base_path, strerror(errno), errno));
        goto fail;
    }

    /* Open the root folder */
    mapi_object_init(&obj_store);
    retval = OpenUserMailbox(session, mdata->username, &obj_store);
        if (retval != MAPI_E_SUCCESS) {
        const char *error = mapi_get_errstr(GetLastError());
        DEBUG(0, ("[!] OpenUserMailbox: %s\n", error));
        goto fail;
    }

    /* Import the directory */
    while ((direntp = readdir(dirp)) != NULL) {
        if (strncasecmp(direntp->d_name, "0x", 2) == 0) {
            /* This is the root folder */
            char *path = talloc_asprintf(mem_ctx, "%s/%s", base_path, direntp->d_name);
            retval = import_directory(mem_ctx, mdata, &obj_store, NULL, path);
            if (retval != MAPI_E_SUCCESS) {
                DEBUG(0, ("import_directory failed with %s\n",
                    mapi_get_errstr(GetLastError())));
                break;
            }
            talloc_free(path);
            break;
        }
    }

fail:
    mapi_object_release(&obj_store);
    if (dirp)
        closedir(dirp);
    if (mdata->tdb_foldermap) {
        tdb_close(mdata->tdb_foldermap);
        mdata->tdb_foldermap = NULL;
    }
    if (mdata->tdb_sysfolder) {
        tdb_close(mdata->tdb_sysfolder);
        mdata->tdb_sysfolder = NULL;
    }
    if (base_path)
        talloc_free(base_path);
    mdata->end_time = time(NULL);
    return;
}


void *import_start_thread(void *arg)
{
    struct status       *status;
    struct mbox_data    *data;
    int         i;

    status =  (struct status *) arg;
    DEBUG(1, ("[*] Importing thread started\n"));
    status->state = STATE_IMPORTING;
    status->start_time = time(NULL);

    for (i = 0; i < array_list_length(status->mbox_list); i++) {
        data = (struct mbox_data *) array_list_get_idx(status->mbox_list, i);
        // FIXME: first argument should be a TALLOC_CTX *mem_ctx!!!
        import_mailbox(data, status->local.session, data);
    }
    status->state = STATE_IMPORTED;
    status->end_time = time(NULL);
    DEBUG(1, ("[*] Importing thread stopped\n"));
    return NULL;
}

#ifndef __MIGRATE_H__
#define __MIGRATE_H__

#include <libmapi/libmapi.h>
#include <amqp.h>
#include <stdbool.h>
#include <pthread.h>

#define DEFAULT_EXPORT_PATH     "/var/tmp/openchange-migrate"

struct mbox_tree_item {
    struct mbox_tree_item *parent;
    struct mbox_tree_item *children;
    struct mbox_tree_item *next;
    struct mbox_tree_item *prev;
    mapi_id_t id;
    char *name;
    char *path;
};

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

struct mbox_data {
    const char      *username;

    int64_t         MailboxSize;
    uint32_t        FolderCount;
    struct mailboxitems items;
    struct mbox_tree_item *tree_root;
};

enum state
{
    STATE_IDLE,
    STATE_ESTIMATING,
    STATE_ESTIMATED,
    STATE_MIGRATING,
};

struct status
{
    /* Command line parameters */
    bool opt_dumpdata;
    int  opt_debug;
    char *opt_profdb;
//    char *opt_profname;
//    char *opt_password;
//    char *opt_username;

    /* AMQP connection */
    amqp_connection_state_t conn;

    /* RPC run loop flag */
    bool rpc_run;

    /* JSON parser */
    struct json_tokener *tokener;

    /* Internal state */
    enum state state;
    struct TALLOC_CTX   *mem_ctx;
    struct mapi_context *mapi_ctx;
    struct mapi_session *session;
    pthread_t thread_id;

    /* Array of mailboxes */
    struct array_list *mbox_list; //struct mailboxdata  mdata;
};

void mbox_data_free(void *data);
void *mbox_start_estimate_thread(void *arg);

#endif

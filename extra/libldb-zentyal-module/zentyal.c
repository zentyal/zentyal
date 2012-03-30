/*
   ldb database library

   Copyright (C) 2012 eBox Technologies S.L.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License, version 2, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

/*
 *  Name: ldb
 *
 *  Component: ldb zentyal module
 *
 *  Description: example module
 *
 *  Author: Samuel Cabrero
 */

#include <EXTERN.h>               /* from the Perl distribution     */
#include <perl.h>                 /* from the Perl distribution     */
#include <syslog.h>
#include "ldb_module.h"

PerlInterpreter *my_perl = NULL;  /***    The Perl interpreter    ***/

struct private_data
{
	char *some_private_data;
};

static void zentyal_dump_dn(struct ldb_dn *dn)
{
    syslog(LOG_INFO, "cn=%s", ldb_dn_get_linearized(dn));
}

static void zentyal_dump_msg(const struct ldb_message *msg)
{
    int i,j;

    zentyal_dump_dn(msg->dn);
    for (i=0; i<msg->num_elements; i++)
    {
        struct ldb_message_element *elem = &(msg->elements[i]);
        syslog(LOG_INFO, "element: %s", elem->name);
        for (j=0; j<elem->num_values; j++)
        {
            struct ldb_val *val = &(elem->values[j]);
            if( strcmp(elem->name, "unicodePwd")==0)
            {
                int k;
                for (k=0;k<val->length;k++) {
                    syslog(LOG_INFO, "0x%X", val->data[k]);
                }
            }
            else
            {
                syslog(LOG_INFO, "length: %i, value: %s", val->length, (char *)(val->data));
            }
        }
    }
}

static void zentyal_dump_req(struct ldb_request *req)
{
    switch(req->operation)
    {
        case LDB_SEARCH:
            syslog(LOG_INFO, "Module zentyal: SEARCH");
            break;
	    case LDB_ADD:
            syslog(LOG_INFO, "Module zentyal: ADD");
            zentyal_dump_msg(req->op.add.message);
            break;
	    case LDB_MODIFY:
            syslog(LOG_INFO, "Module zentyal: MODIFY");
            zentyal_dump_msg(req->op.mod.message);
            break;
	    case LDB_DELETE:
            syslog(LOG_INFO, "Module zentyal: DELETE");
            break;
	    case LDB_RENAME:
            syslog(LOG_INFO, "Module zentyal: RENAME");
            zentyal_dump_dn(req->op.del.dn);
            break;
	    case LDB_EXTENDED:
            syslog(LOG_INFO, "Module zentyal: EXTENDED");
            break;
	    case LDB_REQ_REGISTER_CONTROL:
            syslog(LOG_INFO, "Module zentyal: REGISTER CONTROL");
            break;
	    case LDB_REQ_REGISTER_PARTITION:
            syslog(LOG_INFO, "Module zentyal: REGISTER PARTITION");
            break;
        default:
            syslog(LOG_INFO, "Module zentyal: Unkonwn operation type");
            break;
    }
}

/* search */
static int zentyal_search(struct ldb_module *module, struct ldb_request *req)
{
    syslog(LOG_INFO, "Module zentyal: search");
    zentyal_dump_req(req);
	return ldb_next_request(module, req);
}

/* add */
static int zentyal_add(struct ldb_module *module, struct ldb_request *req){
    syslog(LOG_INFO, "Module zentyal: add");
    zentyal_dump_req(req);
	return ldb_next_request(module, req);
}

/* modify */
static int zentyal_modify(struct ldb_module *module, struct ldb_request *req)
{
    syslog(LOG_INFO, "Module zentyal: modify");
    zentyal_dump_req(req);
	return ldb_next_request(module, req);
}

/* delete */
static int zentyal_delete(struct ldb_module *module, struct ldb_request *req)
{
    syslog(LOG_INFO, "Module zentyal: delete");
    zentyal_dump_req(req);
	return ldb_next_request(module, req);
}

/* rename */
static int zentyal_rename(struct ldb_module *module, struct ldb_request *req)
{
    syslog(LOG_INFO, "Module zentyal: rename");
    zentyal_dump_req(req);
	return ldb_next_request(module, req);
}

/* start a transaction */
static int zentyal_start_trans(struct ldb_module *module)
{
    syslog(LOG_INFO, "Module zentyal: start_trans");
	return ldb_next_start_trans(module);
}

/* end a transaction */
static int zentyal_end_trans(struct ldb_module *module)
{
    syslog(LOG_INFO, "Module zentyal: end_trans");
	return ldb_next_end_trans(module);
}

/* delete a transaction */
static int zentyal_del_trans(struct ldb_module *module)
{
    syslog(LOG_INFO, "Module zentyal: del_trans");
	return ldb_next_del_trans(module);
}

static int zentyal_destructor(struct ldb_module *ctx)
{
	struct private_data *data;

	data = talloc_get_type(ldb_module_get_private(ctx), struct private_data);

	/* put your clean-up functions here */
	if (data->some_private_data) talloc_free(data->some_private_data);

    syslog(LOG_INFO, "Module zentyal: destructor");
	return 0;
}

static int zentyal_request(struct ldb_module *module, struct ldb_request *req)
{
    syslog(LOG_INFO, "Module zentyal: request");
	return ldb_next_request(module, req);
}

static int zentyal_init(struct ldb_module *module)
{
	struct ldb_context *ldb;
	struct private_data *data;

	ldb = ldb_module_get_ctx(module);

	data = talloc(module, struct private_data);
	if (data == NULL) {
		ldb_oom(ldb);
		return LDB_ERR_OPERATIONS_ERROR;
	}

	data->some_private_data = NULL;
	ldb_module_set_private(module, data);

	talloc_set_destructor (module, zentyal_destructor);

    syslog(LOG_INFO, "Module zentyal initialized");

	return ldb_next_init(module);
}

static const struct ldb_module_ops ldb_zentyal_module_ops = {
	.name		       = "zentyal",
	.init_context	   = zentyal_init,
//	.search            = zentyal_search,
	.add               = zentyal_add,
	.modify            = zentyal_modify,
	.del               = zentyal_delete,
	.rename            = zentyal_rename,
	.request      	   = zentyal_request,
	.start_transaction = zentyal_start_trans,
	.end_transaction   = zentyal_end_trans,
	.del_transaction   = zentyal_del_trans,
};

int ldb_init_module(const char *version)
{
    syslog(LOG_INFO, "Module zentyal registered, version %s", version);
	LDB_MODULE_CHECK_VERSION(version);

    if (my_perl == NULL) {
        syslog(LOG_INFO, "Allocating perl interpreter");
        my_perl = perl_alloc();
        perl_construct(my_perl);
    //    perl_parse(my_perl, NULL, argc, argv, (char **)NULL);
    //    //perl_destruct(my_perl);
    //    //perl_free(my_perl);
    }

	return ldb_register_module(&ldb_zentyal_module_ops);
}

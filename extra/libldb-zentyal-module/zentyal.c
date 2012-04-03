/*
   ldb database zentyal module

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
 *  Name: zentyal
 *
 *  Component: ldb zentyal module
 *
 *  Description: Intercept LDB operations and forward them to the synchronizer
 *               perl script
 *
 *  Author: Samuel Cabrero <scabrero@zentyal.com>
 */

#include <EXTERN.h>               /* from the Perl distribution     */
#include <perl.h>                 /* from the Perl distribution     */
#include "ldb_module.h"

static char perl_script[] = "/home/zen/s4sync";

extern void xs_init (pTHX);

struct private_data
{
};

static PerlInterpreter *my_perl = NULL;

static void msg_to_hash(const struct ldb_message *msg, SV **dn, SV **hash)
{
    if (dn) {
        const char *linear_dn;
        linear_dn = ldb_dn_get_linearized(msg->dn);
        *dn = newSVpv(linear_dn, strlen(linear_dn));
    }

    if (hash) {
        int i, j;
        HV *entry = (HV *)sv_2mortal((SV *)newHV());
        for (i = 0; i < msg->num_elements; i++) {
            const struct ldb_message_element *elem = &msg->elements[i];

            AV *valuesArray = (AV *)sv_2mortal((SV *)newAV());
            for (j = 0; j < elem->num_values; j++) {
                struct ldb_val *value = &elem->values[j];
                SV *valueScalar = newSVpv((const char *)value->data, (int)value->length);
                av_push(valuesArray, valueScalar);
            }
            hv_store(entry, elem->name, strlen(elem->name), newRV((SV *)valuesArray), 0);
        }
        *hash = newRV((SV *)entry);
    }
}

static int perl_call(const char *function, const struct ldb_message *msg)
{
    int perl_return_value;
    SV *dn;
    SV *hash;

    msg_to_hash(msg, &dn, &hash);

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(dn));
    XPUSHs(sv_2mortal(hash));
    PUTBACK;
    call_pv(function, G_SCALAR);
    SPAGAIN;
    perl_return_value = (int)POPi;
    PUTBACK;
    FREETMPS;
    LEAVE;

    return perl_return_value;
}

static int perl_call_del(const char *function, struct ldb_dn *dn)
{
    int perl_return_value;
    SV *pdn;
    const char *linear_dn;

    linear_dn = ldb_dn_get_linearized(dn);
    pdn = newSVpv(linear_dn, strlen(linear_dn));

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(pdn));
    PUTBACK;
    call_pv(function, G_SCALAR);
    SPAGAIN;
    perl_return_value = (int)POPi;
    PUTBACK;
    FREETMPS;
    LEAVE;

    return perl_return_value;
}

static int perl_call_rename(const char *function,
    struct ldb_dn *olddn, struct ldb_dn *newdn)
{
    int perl_return_value;
    SV *old_pdn;
    SV *new_pdn;
    const char *linear_dn;

    linear_dn = ldb_dn_get_linearized(olddn);
    old_pdn = newSVpv(linear_dn, strlen(linear_dn));
    linear_dn = ldb_dn_get_linearized(newdn);
    new_pdn = newSVpv(linear_dn, strlen(linear_dn));

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(old_pdn));
    XPUSHs(sv_2mortal(new_pdn));
    PUTBACK;
    call_pv(function, G_SCALAR);
    SPAGAIN;
    perl_return_value = (int)POPi;
    PUTBACK;
    FREETMPS;
    LEAVE;

    return perl_return_value;
}

static int zentyal_add(struct ldb_module *module, struct ldb_request *req)
{
    int ret;

    if (req->operation == LDB_ADD)
        ret = perl_call("addToLdap", req->op.add.message);

    return ldb_next_request(module, req);
}

static int zentyal_modify(struct ldb_module *module, struct ldb_request *req)
{
    int ret;

    if (req->operation == LDB_MODIFY)
        ret = perl_call("modifyInLdap", req->op.mod.message);

	return ldb_next_request(module, req);
}

static int zentyal_delete(struct ldb_module *module, struct ldb_request *req)
{
    int ret;

    if (req->operation == LDB_DELETE)
        ret = perl_call_del("deleteFromLdap", req->op.del.dn);

	return ldb_next_request(module, req);
}

static int zentyal_rename(struct ldb_module *module, struct ldb_request *req)
{
    int ret;

    if (req->operation == LDB_RENAME)
        ret = perl_call_rename("renameInLdap", req->op.rename.olddn, req->op.rename.newdn);

	return ldb_next_request(module, req);
}

static int zentyal_start_trans(struct ldb_module *module)
{
    // TODO Implement transactions
	return ldb_next_start_trans(module);
}

static int zentyal_end_trans(struct ldb_module *module)
{
    // TODO Implement transactions
	return ldb_next_end_trans(module);
}

static int zentyal_del_trans(struct ldb_module *module)
{
    // TODO Implement transactions
	return ldb_next_del_trans(module);
}

static int zentyal_prepare_commit(struct ldb_module *module)
{
    // TODO Implement transactions
    return ldb_next_prepare_commit(module);
}

static int zentyal_request(struct ldb_module *module, struct ldb_request *req)
{
	return ldb_next_request(module, req);
}

static int zentyal_destructor(struct ldb_module *ctx)
{
	struct private_data *data;

	data = talloc_get_type(ldb_module_get_private(ctx), struct private_data);

    // Destruct and free perl interpreter
    if (my_perl != NULL) {
        perl_destruct(my_perl);
        perl_free(my_perl);
        PERL_SYS_TERM();
        my_perl = NULL;
    }

	// Free private data
    talloc_free(data);

	return 0;
}

static int zentyal_init(struct ldb_module *module)
{
	struct ldb_context *ldb;
	struct private_data *data;

	ldb = ldb_module_get_ctx(module);

    // Init private data
	data = talloc(module, struct private_data);
	if (data == NULL) {
		ldb_oom(ldb);
		return LDB_ERR_OPERATIONS_ERROR;
	}
	ldb_module_set_private(module, data);

    // Init perl interpreter
    if (my_perl == NULL) {
        PERL_SYS_INIT3(NULL, NULL, NULL);
        my_perl = perl_alloc();
        perl_construct(my_perl);

        char *perl_argv[] = { "", perl_script };
        perl_parse(my_perl, xs_init, 2, perl_argv, (char **)NULL);
        PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
        perl_run(my_perl);
    }

	talloc_set_destructor (module, zentyal_destructor);

	return ldb_next_init(module);
}

static const struct ldb_module_ops ldb_zentyal_module_ops = {
	.name		       = "zentyal",
	.init_context	   = zentyal_init,
	.add               = zentyal_add,
	.modify            = zentyal_modify,
	.del               = zentyal_delete,
	.rename            = zentyal_rename,
	.request      	   = zentyal_request,
	.start_transaction = zentyal_start_trans,
	.end_transaction   = zentyal_end_trans,
	.del_transaction   = zentyal_del_trans,
    .prepare_commit    = zentyal_prepare_commit,
};

int ldb_init_module(const char *version)
{
	LDB_MODULE_CHECK_VERSION(version);
    return ldb_register_module(&ldb_zentyal_module_ops);
}

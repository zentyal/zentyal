#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "ldb.h"

struct search_context {
	struct ldb_context *ldb;
	struct ldb_control **req_ctrls;

	int sort;
	unsigned int num_stored;
	struct ldb_message **store;
	unsigned int refs_stored;
	char **refs_store;

	unsigned int entries;
	unsigned int refs;

	unsigned int pending;
	int status;
};

static int store_message(struct ldb_message *msg, struct search_context *sctx)
{
	sctx->store = talloc_realloc(sctx, sctx->store, struct ldb_message *, sctx->num_stored + 2);
	if (!sctx->store) {
		fprintf(stderr, "talloc_realloc failed while storing messages\n");
		return -1;
	}

	sctx->store[sctx->num_stored] = talloc_move(sctx->store, &msg);
	sctx->num_stored++;
	sctx->store[sctx->num_stored] = NULL;

	return 0;
}

static int store_referral(char *referral, struct search_context *sctx)
{
	sctx->refs_store = talloc_realloc(sctx, sctx->refs_store, char *, sctx->refs_stored + 2);
	if (!sctx->refs_store) {
		fprintf(stderr, "talloc_realloc failed while storing referrals\n");
		return -1;
	}

	sctx->refs_store[sctx->refs_stored] = talloc_move(sctx->refs_store, &referral);
	sctx->refs_stored++;
	sctx->refs_store[sctx->refs_stored] = NULL;

	return 0;
}

static int do_compare_msg(struct ldb_message **el1,
			  struct ldb_message **el2,
			  void *opaque)
{
	return ldb_dn_compare((*el1)->dn, (*el2)->dn);
}

static int search_callback(struct ldb_request *req, struct ldb_reply *ares)
{
	struct search_context *sctx;
	int ret = LDB_SUCCESS;

	sctx = talloc_get_type(req->context, struct search_context);

	if (!ares) {
		return ldb_request_done(req, LDB_ERR_OPERATIONS_ERROR);
	}
	if (ares->error != LDB_SUCCESS) {
		return ldb_request_done(req, ares->error);
	}

	switch (ares->type) {
	case LDB_REPLY_ENTRY:
		ret = store_message(ares->message, sctx);
		break;

	case LDB_REPLY_REFERRAL:
		ret = store_referral(ares->referral, sctx);
		if (ret) {
			return ldb_request_done(req, LDB_ERR_OPERATIONS_ERROR);
		}
		break;

	case LDB_REPLY_DONE:
		if (ares->controls) {
			if (handle_controls_reply(ares->controls, sctx->req_ctrls) == 1)
				sctx->pending = 1;
		}
		talloc_free(ares);
		return ldb_request_done(req, LDB_SUCCESS);
	}

	talloc_free(ares);
	if (ret != LDB_SUCCESS) {
		return ldb_request_done(req, LDB_ERR_OPERATIONS_ERROR);
	}

	return LDB_SUCCESS;
}

static int do_search(struct ldb_context *ldb,
                     struct ldb_dn *basedn,
                     enum ldb_scope scope,
		             const char *expression,
		             const char * const *attrs,
                     struct search_context *sctx)
{
	struct ldb_request *req = NULL;
	int ret;

again:
	/* free any previous requests */
	if (req) talloc_free(req);

	ret = ldb_build_search_req(&req, ldb, ldb,
				   basedn, scope,
				   expression, attrs,
				   sctx->req_ctrls,
				   sctx, search_callback,
				   NULL);
	if (ret != LDB_SUCCESS) {
		talloc_free(sctx);
		printf("allocating request failed: %s\n", ldb_errstring(ldb));
		return ret;
	}

	if (basedn == NULL) {
		/*
		  we need to use a NULL base DN when doing a cross-ncs
		  search so we find results on all partitions in a
		  forest. When doing a domain-local search, default to
		  the default basedn
		 */
		struct ldb_control *ctrl;
		struct ldb_search_options_control *search_options = NULL;

		ctrl = ldb_request_get_control(req, LDB_CONTROL_SEARCH_OPTIONS_OID);
		if (ctrl) {
			search_options = talloc_get_type(ctrl->data, struct ldb_search_options_control);
		}

		if (ctrl == NULL || search_options == NULL ||
		    !(search_options->search_options & LDB_SEARCH_OPTION_PHANTOM_ROOT)) {
			struct ldb_dn *base = ldb_get_default_basedn(ldb);
			if (base != NULL) {
				req->op.search.base = base;
			}
		}
	}

	sctx->pending = 0;

	ret = ldb_request(ldb, req);
	if (ret != LDB_SUCCESS) {
		printf("search failed - %s\n", ldb_errstring(ldb));
		return ret;
	}

	ret = ldb_wait(req->handle, LDB_WAIT_ALL);
	if (ret != LDB_SUCCESS) {
		printf("search error - %s\n", ldb_errstring(ldb));
		return ret;
	}

	if (sctx->pending)
		goto again;

	//if (sctx->sort && (sctx->num_stored != 0 || sctx->refs != 0)) {
	//	unsigned int i;

		if (sctx->num_stored) {
			LDB_TYPESAFE_QSORT(sctx->store, sctx->num_stored, ldb, do_compare_msg);
		}
	//	for (i = 0; i < sctx->num_stored; i++) {
	//		display_message(sctx->store[i], sctx);
	//	}

	//	for (i = 0; i < sctx->refs_stored; i++) {
	//		display_referral(sctx->refs_store[i], sctx);
	//	}
	//}

	talloc_free(req);

	return LDB_SUCCESS;

}

MODULE = LDB		PACKAGE = LDB
int
search(url, baseStr, scopeStr, filterStr, attrsStr)
        const char *url
        const char *baseStr
        const char *scopeStr
        const char *filterStr
        const char *attrsStr
    CODE:
        struct ldb_context *ldb = NULL;
        struct ldb_dn *basedn = NULL;
        struct search_context *sctx = NULL;

        enum ldb_scope scope = LDB_SCOPE_DEFAULT;
        const char * const * attrs = NULL;
        const char *expression = "(|(objectClass=*)(distinguishedName=*))";
        int ret = LDB_ERR_OPERATIONS_ERROR;

        //if (strcmp(scopeStr, "base") == 0) {
        //	scope = LDB_SCOPE_BASE;
        //} else if (strcmp(scopeStr, "sub") == 0) {
        //	scope = LDB_SCOPE_SUBTREE;
        //} else if (strcmp(scopeStr, "one") == 0) {
        //	scope = LDB_SCOPE_ONELEVEL;
        //} else {
        //    RETVAL = LDB_ERR_OPERATIONS_ERROR;
        //    goto out;
        //}

        TALLOC_CTX *mem_ctx = talloc_new(NULL);
        ldb = ldb_init(mem_ctx, NULL);
        if (ldb == NULL) {
            RETVAL = LDB_ERR_OPERATIONS_ERROR;
            goto failure;
        }

        if (baseStr != NULL) {
            basedn = ldb_dn_new(ldb, ldb, baseStr);
            if (basedn == NULL) {
                RETVAL = LDB_ERR_OPERATIONS_ERROR;
                goto failure_connect;
            }
        }

	    if (ldb_connect(ldb, url, 0, NULL) != LDB_SUCCESS) {
            RETVAL = LDB_ERR_OPERATIONS_ERROR;
            goto failure_connect;
        }


        // Declare context here to access the stored search result
        sctx = talloc_zero(ldb, struct search_context);
    	if (sctx == NULL) {
            RETVAL = LDB_ERR_OPERATIONS_ERROR;
            goto failure_connect;
        }
	    sctx->ldb = ldb;
	    sctx->sort = 0;
        sctx->req_ctrls = ldb_parse_control_strings(ldb, sctx, (const char **)NULL);

        ret = do_search(ldb, NULL, scope, expression, attrs, sctx);
        if (ret != LDB_SUCCESS) {
            RETVAL = ret;
            goto failure_connect;
        }

        // Convert the results to perl
	    printf("# returned %u records\n# %u entries\n# %u referrals\n",
		    sctx->num_stored + sctx->refs_stored, sctx->num_stored, sctx->refs_stored);

        int i;
	    for (i = 0; i < sctx->num_stored; i++) {
            struct ldb_ldif ldif;

	        ldif.changetype = LDB_CHANGETYPE_NONE;
	        ldif.msg = sctx->store[i];

	        printf("# record %d\n", i);
            int j;
            for (j=0; j<ldif.msg->num_elements; j++) {
                struct ldb_message_element *elem = &ldif.msg->elements[j];
                printf(" key '%s', number of values: %d\n", elem->name, elem->num_values);
            }
	        //ldb_ldif_write_file(sctx->ldb, stdout, &ldif);
	    }

	    talloc_free(sctx);

    failure_connect:
	    talloc_free(ldb);
    failure:
        talloc_free(mem_ctx);
    out:
    OUTPUT:
        RETVAL

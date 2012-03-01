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

	if (sctx->sort && (sctx->num_stored != 0 || sctx->refs != 0)) {
		if (sctx->num_stored) {
			LDB_TYPESAFE_QSORT(sctx->store, sctx->num_stored, ldb, do_compare_msg);
		}
    }

	talloc_free(req);

	return LDB_SUCCESS;

}

MODULE = LDB		PACKAGE = LDB
SV*
search(params)
        HV *params
    INIT:
        AV *results;
        if (!hv_exists(params, "url", 3)) {
            croak("missing 'url' key");
        }
        results = (AV *)sv_2mortal((SV *)newAV());
    CODE:
        struct ldb_context *ldb = NULL;
        struct search_context *sctx = NULL;
        int ret = -1;

        // Get the url
        SV **urlParam = hv_fetch(params, "url", 3, 0);
        const char *url = SvPV_nolen(*urlParam);

        // Get the base DN
        const char *baseStr = NULL;
        if (hv_exists(params, "base", 4)) {
            SV **baseParam = hv_fetch(params, "base", 4, 0);
            baseStr = SvPV_nolen(*baseParam);
        }

        // Get the scope
        enum ldb_scope scope = LDB_SCOPE_DEFAULT;
        if (hv_exists(params, "scope", 5)) {
            SV **scopeParam = hv_fetch(params, "scope", 5, 0);
            const char *scopeStr = SvPV_nolen(*scopeParam);
            if (strcmp(scopeStr, "base") == 0) {
            	scope = LDB_SCOPE_BASE;
            } else if (strcmp(scopeStr, "sub") == 0) {
            	scope = LDB_SCOPE_SUBTREE;
            } else if (strcmp(scopeStr, "one") == 0) {
            	scope = LDB_SCOPE_ONELEVEL;
            } else {
                croak("Invalid scope");
            }
        }

        // Get the filter
        const char *filter = "(|(objectClass=*)(distinguishedName=*))";
        if (hv_exists(params, "filter", 6)) {
            SV **filterParam = hv_fetch(params, "filter", 6, 0);
            filter = SvPV_nolen(*filterParam);
        }

        // Get the requested attributes
        const char ** attrs = NULL;
        if (hv_exists(params, "attrs", 5)) {
            SV **attrsParam = hv_fetch(params, "attrs", 5, 0);
            int attrsCount = av_len((AV *)SvRV(*attrsParam)) + 1;
            attrs = (const char **)calloc(sizeof(char*), attrsCount + 1);
            int n;
            for (n = 0; n < attrsCount; n++) {
                const char *attr = SvPV_nolen(*av_fetch((AV *)SvRV(*attrsParam), n, 0));
                attrs[n] = attr;
            }
        }

        TALLOC_CTX *mem_ctx = talloc_new(NULL);
        ldb = ldb_init(mem_ctx, NULL);
        if (ldb == NULL) {
            talloc_free(mem_ctx);
            free(attrs);
            croak("%s", ldb_strerror(LDB_ERR_OTHER));
        }

        // Register samba LDB handlers to translate the stored
        //  attributes from NDR format to LDIF format
        ret = ldb_register_samba_handlers(ldb);
        if (ret != LDB_SUCCESS) {
            croak("%s", "Can't register samba handlers");
        }

        struct ldb_dn *basedn = NULL;
        if (baseStr != NULL) {
            basedn = ldb_dn_new(ldb, ldb, baseStr);
            if (basedn == NULL) {
	            talloc_free(ldb);
                talloc_free(mem_ctx);
                free(attrs);
                croak("%s", ldb_strerror(LDB_ERR_OTHER));
            }
        }

        ret = ldb_connect(ldb, url, 0, NULL);
        if (ret != LDB_SUCCESS) {
	        talloc_free(ldb);
            talloc_free(mem_ctx);
            free(attrs);
            croak("%s", ldb_strerror(LDB_ERR_OTHER));
        }

        // Declare context here to access the stored search result
        sctx = talloc_zero(ldb, struct search_context);
    	if (sctx == NULL) {
	        talloc_free(ldb);
            talloc_free(mem_ctx);
            free(attrs);
            croak("%s", ldb_strerror(LDB_ERR_OTHER));
        }
	    sctx->ldb = ldb;
	    sctx->sort = 1;
        sctx->req_ctrls = ldb_parse_control_strings(ldb, sctx, (const char **)NULL);

        ret = do_search(ldb, basedn, scope, filter, attrs, sctx);
        if (ret != LDB_SUCCESS) {
	        talloc_free(sctx);
	        talloc_free(ldb);
            talloc_free(mem_ctx);
            free(attrs);
            croak("%s", ldb_strerror(ret));
        }

        // Convert the results to perl
        int i;
	    for (i = 0; i < sctx->num_stored; i++) {
            struct ldb_ldif ldif;
	        ldif.changetype = LDB_CHANGETYPE_NONE;
	        ldif.msg = sctx->store[i];

            HV *entry = (HV *)sv_2mortal((SV *)newHV());
            int j;
            for (j=0; j<ldif.msg->num_elements; j++) {
                const struct ldb_schema_attribute *a = NULL;
                TALLOC_CTX *mem_ctx = NULL;
                mem_ctx = talloc_new(NULL);

                struct ldb_message_element *elem = &ldif.msg->elements[j];
                a = ldb_schema_attribute_by_name(ldb, elem->name);
                if (a == NULL) {
                    croak("%s", "Can't get schema attribute");
                }

                AV *valuesArray = (AV *)sv_2mortal((SV *)newAV());
                int k;
                for (k=0; k<elem->num_values; k++) {
                    struct ldb_val *value = &elem->values[k];
                    struct ldb_val printable_value;
                    if (LDB_SUCCESS == a->syntax->ldif_write_fn(ldb, mem_ctx, value, &printable_value) ) {
                        SV *valueScalar = newSVpv((const char *)printable_value.data, (int)printable_value.length);
                        av_push(valuesArray, valueScalar);
                    }
                }

                talloc_free(mem_ctx);
                hv_store(entry, elem->name, strlen(elem->name), newRV((SV *)valuesArray), 0);
            }
            if (HvKEYS(entry) > 0) {
                av_push(results, newRV((SV *)entry));
            }
	    }

        RETVAL = newRV((SV *)results);
	    talloc_free(sctx);
	    talloc_free(ldb);
        talloc_free(mem_ctx);
        free(attrs);

    OUTPUT:
        RETVAL

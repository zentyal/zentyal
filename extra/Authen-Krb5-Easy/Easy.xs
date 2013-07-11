#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include<krb5.h>
#include<string.h>
#include<stdlib.h>
#include<time.h>

char *krb_error_while_doing;
const char *krb_error_string;
int krb_error_code;
time_t krb_expires;

MODULE = Authen::Krb5::Easy     PACKAGE = Authen::Krb5::Easy

#ifndef bool
#   define bool int
#endif
#ifndef false
#   define false 0
#endif
#ifndef true
#   define true !false
#endif

BOOT:
    krb_error_while_doing = NULL;
    krb_error_string = NULL;
    krb_error_code = 0;
    krb_expires = 0;

int
kinit_pwd(principle, password)
    char *principle
    char *password
#   /* returns
#    *  0   - success
#    *  other   - krb5 error code
#    */
    CODE:
        krb5_error_code code = 0;
        krb5_context context;
        krb5_ccache ccache;
        krb5_ccache tempccache;
        krb5_principal princ;
        krb5_get_init_creds_opt *options;
        krb5_init_creds_context ctx;
        krb5_creds creds;
        int parseflags = 0;
        krb5_deltat start_time = 0;

        krb_error_while_doing = NULL;
        krb_error_string = NULL;
        krb_error_code = 0;

        code = krb5_init_context(&context);
        if(code)
        {
            krb_error_while_doing = "could not initialize krb5 context";
            krb_error_string = (char *)error_message(code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_parse_name_flags(context, principle, parseflags, &princ);
        if(code)
        {
            krb_error_while_doing = "could not parse principal name";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_cc_default(context, &ccache);
        if(code)
        {
            krb_error_while_doing = "could not get default ccache";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_get_init_creds_opt_alloc(context, &options);
        if(code)
        {
            krb_error_while_doing =
                "could not allocate credential options structure";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        krb5_get_init_creds_opt_set_forwardable(options, 0);
        krb5_get_init_creds_opt_set_proxiable(options, 0);

        krb5_get_init_creds_opt_set_default_flags(context, "Authen::Krb5::Easy",
            krb5_principal_get_realm(context, princ), options);

        code = krb5_init_creds_init(context, princ, krb5_prompter_posix,
            NULL, start_time, options, &ctx);
        if(code)
        {
            krb_error_while_doing =
                "could not create a context for acquiring initial credentials";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_init_creds_set_password(context, ctx, password);
        if(code != 0)
        {
            krb_error_while_doing = "could not set the password to "
                "use for acquiring initial credentials";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_init_creds_get(context, ctx);
        if(code != 0)
        {
            krb_error_while_doing = "could not acquire credentials using"
                " an initial credentials context";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        krb5_process_last_request(context, options, ctx);

        code = krb5_init_creds_get_creds(context, ctx, &creds);
        if(code != 0)
        {
            krb_error_while_doing = "could not retrieve acquired credentials"
                " from an initial credentials context";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        krb_expires = creds.times.endtime;

        code = krb5_cc_new_unique(context, krb5_cc_get_type(context, ccache),
            NULL, &tempccache);
        if(code != 0)
        {
            krb_error_while_doing = "could not create a new credential cache";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_init_creds_store(context, ctx, tempccache);
        if(code != 0)
        {
            krb_error_while_doing = "could not store credentials";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        krb5_init_creds_free(context, ctx);

        code = krb5_cc_move(context, tempccache, ccache);
        if(code != 0)
        {
            krb_error_while_doing = "could not store credentials";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }


        krb5_get_init_creds_opt_free(context, options);

        krb5_free_principal(context, princ);
        krb5_free_context (context);

#       /*atexit(kdestroy_atexit);*/
        RETVAL=1;
    OUTPUT:
        RETVAL

# /* equivilent to calling kinit -k -t keytab principle */

int
kinit(keytab_name, principle)
    char *keytab_name
    char *principle
#   /* returns
#    *  0   - success
#    *  other   - krb5 error code
#    */
    CODE:
        krb5_error_code code = 0;
        krb5_context context;
        krb5_ccache ccache;
        krb5_ccache tempccache;
        krb5_principal princ;
        krb5_keytab keytab = NULL;
        krb5_get_init_creds_opt *options;
        krb5_init_creds_context ctx;
        krb5_creds creds;
        int parseflags = 0;
        krb5_deltat start_time = 0;

        krb_error_while_doing = NULL;
        krb_error_string = NULL;
        krb_error_code = 0;

        code = krb5_init_context(&context);
        if(code)
        {
            krb_error_while_doing = "could not initialize krb5 context";
            krb_error_string = (char *)error_message(code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_parse_name_flags(context, principle, parseflags, &princ);
        if(code)
        {
            krb_error_while_doing = "could not parse principal name";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_cc_default(context, &ccache);
        if(code)
        {
            krb_error_while_doing = "could not get default ccache";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_get_init_creds_opt_alloc(context, &options);
        if(code)
        {
            krb_error_while_doing =
                "could not allocate credential options structure";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        krb5_get_init_creds_opt_set_forwardable(options, 0);
        krb5_get_init_creds_opt_set_proxiable(options, 0);

        krb5_get_init_creds_opt_set_default_flags(context, "Authen::Krb5::Easy",
            krb5_principal_get_realm(context, princ), options);

        code = krb5_init_creds_init(context, princ, krb5_prompter_posix,
            NULL, start_time, options, &ctx);
        if(code)
        {
            krb_error_while_doing =
                "could not create a context for acquiring initial credentials";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_kt_resolve(context, keytab_name, &keytab);
        if(code != 0)
        {
            krb_error_while_doing = "could not resolve keytab";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_init_creds_set_keytab(context, ctx, keytab);
        if(code != 0)
        {
            krb_error_while_doing = "could not set the keytab to "
                "use for acquiring initial credentials";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_init_creds_get(context, ctx);
        if(code != 0)
        {
            krb_error_while_doing = "could not acquire credentials using"
                " an initial credentials context";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        krb5_process_last_request(context, options, ctx);

        code = krb5_init_creds_get_creds(context, ctx, &creds);
        if(code != 0)
        {
            krb_error_while_doing = "could not retrieve acquired credentials"
                " from an initial credentials context";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        krb_expires = creds.times.endtime;

        code = krb5_cc_new_unique(context, krb5_cc_get_type(context, ccache),
            NULL, &tempccache);
        if(code != 0)
        {
            krb_error_while_doing = "could not create a new credential cache";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        code = krb5_init_creds_store(context, ctx, tempccache);
        if(code != 0)
        {
            krb_error_while_doing = "could not store credentials";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }

        krb5_init_creds_free(context, ctx);

        code = krb5_cc_move(context, tempccache, ccache);
        if(code != 0)
        {
            krb_error_while_doing = "could not store credentials";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }


        krb5_get_init_creds_opt_free(context, options);

        krb5_kt_close(context, keytab);

        krb5_free_principal(context, princ);
        krb5_free_context (context);

#       /*atexit(kdestroy_atexit);*/
        RETVAL=1;
    OUTPUT:
        RETVAL

#/* equivilent to calling kdestory */

int
kdestroy()
#   /* returns
#    *  0   - success
#    *  other   - krb5 error code
#    */
    CODE:
        krb5_context context;
        krb5_error_code code;
        krb5_ccache ccache = NULL;

        krb_error_while_doing = NULL;
        krb_error_string = NULL;
        krb_error_code = 0;

        code = krb5_init_context(&context);
        if(code)
        {
            krb_error_while_doing = "unable to initialize context";
            krb_error_string = (char *)error_message(code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        code = krb5_cc_default(context, &ccache);
        if(code)
        {
            krb_error_while_doing = "could not get default ccache";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        code = krb5_cc_destroy(context, ccache);
        if(code)
        {
            krb_error_while_doing = "unable to destroy ccache";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        krb5_free_context(context);
        RETVAL=1;
    OUTPUT:
        RETVAL

# /* time until ticket expires */
time_t
kexpires()
#   /* return:
#    *  0   - error
#    *  other   - time of experation
#    */
    CODE:
        krb5_context context;
        krb5_error_code code;
        krb5_ccache ccache = NULL;
        krb5_cc_cursor current;
        krb5_creds creds;
        krb5_principal princ;
        krb5_flags flags;
        bool expired = true;
        time_t earliest = 0;

        krb_error_while_doing = NULL;
        krb_error_string = NULL;
        krb_error_code = 0;

        code = krb5_init_context(&context);
        if(code)
        {
            krb_error_while_doing = "unable to initialize context";
            krb_error_string = (char *)error_message(code);
            krb_error_code = code;
            XSRETURN_IV(0);
        }
        code = krb5_cc_default(context, &ccache);
        if(code)
        {
            krb_error_while_doing = "could not get default ccache";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_IV(0);
        }
        flags = 0;
        code = krb5_cc_set_flags(context, ccache, flags);
        if(code)
        {
            krb_error_while_doing = "could not set ccache flags";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_IV(0);
        }
        code = krb5_cc_get_principal(context, ccache, &princ);
        if(code)
        {
            krb_error_while_doing = "could not get principle";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_IV(0);
        }
        code = krb5_cc_start_seq_get(context, ccache, &current);
        if(code)
        {
            krb_error_while_doing = "could not start sequential get";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_IV(0);
        }
        code = krb5_cc_next_cred(context, ccache, &current, &creds);
        while(!code && expired)
        {
            if(!strcmp(creds.server->realm, princ->realm) &&
               !strcmp(*(creds.server->name.name_string.val), "krbtgt") &&
               !strcmp(creds.server->realm, princ->realm) &&
               (creds.times.endtime < earliest || !earliest)) {
                    earliest = creds.times.endtime;
            }
            krb5_free_cred_contents(context, &creds);
            code = krb5_cc_next_cred(context, ccache, &current, &creds);
        }
        if(code && code != KRB5_CC_END)
        {
            krb_error_while_doing = "could not read next credential";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_IV(0);
        }
        code = krb5_cc_end_seq_get(context, ccache, &current);
        if(code)
        {
            krb_error_while_doing = "could not finish reading credentials";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_IV(0);
        }
        flags = KRB5_TC_OPENCLOSE;
        code = krb5_cc_set_flags(context, ccache, flags);
        if(code)
        {
            krb_error_while_doing = "could not set ccache flags";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_IV(0);
        }
        krb5_cc_close(context, ccache);
        krb5_free_context(context);
        RETVAL=earliest;
    OUTPUT:
        RETVAL

# /* Retrieve list of credentials in the cache */
AV*
klist()
#   /* return:
#    *  undef on error, the list of credentials on success
#    */
    INIT:
        AV *av_creds = newAV();
    CODE:
        krb5_context context;
        krb5_error_code code;
        krb5_ccache ccache = NULL;
        krb5_cc_cursor current;
        krb5_creds creds;
        krb5_principal princ;
        krb5_flags flags;

        krb_error_while_doing = NULL;
        krb_error_string = NULL;
        krb_error_code = 0;

        code = krb5_init_context(&context);
        if(code)
        {
            krb_error_while_doing = "unable to initialize context";
            krb_error_string = (char *)error_message(code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        code = krb5_cc_default(context, &ccache);
        if(code)
        {
            krb_error_while_doing = "could not get default ccache";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        flags = 0;
        code = krb5_cc_set_flags(context, ccache, flags);
        if(code)
        {
            krb_error_while_doing = "could not set ccache flags";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        code = krb5_cc_start_seq_get(context, ccache, &current);
        if(code)
        {
            krb_error_while_doing = "could not start sequential get";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        code = krb5_cc_next_cred(context, ccache, &current, &creds);
        while(!code)
        {
            size_t j;
            char *str;
            krb5_timestamp sec;
            HV *hv_cred = newHV();

            krb5_timeofday(context, &sec);
            code = krb5_unparse_name(context, creds.server, &str);
            if (code) {
                krb_error_while_doing = "could not convert kerberos principal to text string";
                krb_error_string = krb5_get_error_message(context, code);
                krb_error_code = code;
                XSRETURN_UNDEF;
            }
            hv_store(hv_cred, "server", 6, newSVpv(str, strlen(str)), 0);
            free(str);

            code = krb5_unparse_name(context, creds.client, &str);
            if (code) {
                 krb_error_while_doing = "could not convert kerberos principal to text string";
                krb_error_string = krb5_get_error_message(context, code);
                krb_error_code = code;
                XSRETURN_UNDEF;
            }
            hv_store(hv_cred, "client", 6, newSVpv(str, strlen(str)), 0);
            free(str);

            if (!krb5_is_config_principal(context, creds.client)) {
                Ticket t;
                size_t len;
                char *s;

                decode_Ticket(creds.ticket.data, creds.ticket.length, &t, &len);
                code = krb5_enctype_to_string(context, t.enc_part.etype, &s);
                if (code == 0) {
                    hv_store(hv_cred, "ticket_etype", 12, newSVpv(s, strlen(s)), 0);
                    free(s);
                } else {
                    hv_store(hv_cred, "ticket_etype", 12, newSVuv(t.enc_part.etype), 0);
                }
                if (t.enc_part.kvno) {
                    hv_store(hv_cred, "kvno", 4, newSVuv(*t.enc_part.kvno), 0);
                }

                if (creds.session.keytype != t.enc_part.etype) {
                    code = krb5_enctype_to_string(context, creds.session.keytype, &str);
                    if (code) {
                        krb5_warn(context, code, "session keytype");
                    } else {
                        hv_store(hv_cred, "session_key", 11, newSVpv(str, strlen(str)), 0);
                        free(str);
                    }
                }
                free_Ticket(&t);

                hv_store(hv_cred, "ticket_length", 13, newSVuv(creds.ticket.length), 0);
            }

            hv_store(hv_cred, "auth_time", 9, newSVuv(creds.times.authtime), 0);
            if (creds.times.authtime != creds.times.starttime) {
                hv_store(hv_cred, "start_time", 10, newSVuv(creds.times.starttime), 0);
            }

            hv_store(hv_cred, "end_time", 8, newSVuv(creds.times.endtime), 0);

            if (sec > creds.times.endtime) {
                hv_store(hv_cred, "expired", 7, newSVuv(1), 0);
            } else {
                hv_store(hv_cred, "expired", 7, newSVuv(0), 0);
            }

            if (creds.flags.b.renewable) {
                hv_store(hv_cred, "renew_till", 10, newSVuv(creds.times.renew_till), 0);
            }

            {
                char flags[1024];
                AV *av_flags = newAV();
                unparse_flags(TicketFlags2int(creds.flags.b), asn1_TicketFlags_units(), flags, sizeof(flags));
                char *pch;
                pch = strtok(flags, " ,");
                while (pch != NULL) {
                    av_push(av_flags, newSVpv(pch, strlen(pch)));
                    pch = strtok(NULL, " ,");
                }
                hv_store(hv_cred, "flags", 5, newRV((SV*)av_flags), 0);
            }

            if (creds.addresses.len != 0) {
                AV *addresses = newAV();
                for (j = 0; j < creds.addresses.len; j++) {
                    char buf[128];
                    size_t len;
                    code = krb5_print_address(&creds.addresses.val[j],
                            buf, sizeof(buf), &len);
                    if (code == 0) {
                        av_push(addresses, newSVpv(buf, strlen(buf)));
                    }
                }
                hv_store(hv_cred, "addresses", 9, newRV((SV*)addresses), 0);
            } else {
                hv_store(hv_cred, "addresses", 9, newSV(0), 0);
            }
            av_push(av_creds, newRV((SV*)hv_cred));

            krb5_free_cred_contents(context, &creds);
            code = krb5_cc_next_cred(context, ccache, &current, &creds);
        }
        if(code && code != KRB5_CC_END)
        {
            krb_error_while_doing = "could not read next credential";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        code = krb5_cc_end_seq_get(context, ccache, &current);
        if(code)
        {
            krb_error_while_doing = "could not finish reading credentials";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        flags = KRB5_TC_OPENCLOSE;
        code = krb5_cc_set_flags(context, ccache, flags);
        if(code)
        {
            krb_error_while_doing = "could not set ccache flags";
            krb_error_string = krb5_get_error_message(context, code);
            krb_error_code = code;
            XSRETURN_UNDEF;
        }
        krb5_cc_close(context, ccache);
        krb5_free_context(context);

        av_creds = (AV *)sv_2mortal((SV *)av_creds);
        RETVAL = av_creds;
    OUTPUT:
        RETVAL

# you would think that I could just export the globals, but I can't figure
# out how to do that, so these will sufice:

char *
get_error_while_doing()
    CODE:
        RETVAL = krb_error_while_doing;
    OUTPUT:
        RETVAL

const char *
get_error_string()
    CODE:
        RETVAL = krb_error_string;
    OUTPUT:
        RETVAL

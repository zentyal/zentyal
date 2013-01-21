#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include<krb5.h>
#include<string.h>
#include<stdlib.h>
#include<time.h>

char *krb_error_while_doing;
char *krb_error_string;
int krb_error_code;
time_t krb_expires;

MODULE = Authen::Krb5::Easy		PACKAGE = Authen::Krb5::Easy

#ifndef bool
#	define bool int
#endif
#ifndef false
#	define false 0
#endif
#ifndef true
#	define true !false
#endif

BOOT:
	krb_error_while_doing = NULL;
	krb_error_string = NULL;
	krb_error_code = 0;
	krb_expires = 0;

# /* equivilent to calling kinit -k -t keytab principle */

int
kinit(keytab_name, principle)
	char *keytab_name
	char *principle
# 	/* returns
# 	 * 	0	- success
# 	 * 	other	- krb5 error code
# 	 */
	CODE:
		krb5_error_code code = 0;
		krb5_context context;
		krb5_ccache ccache;
		krb5_principal princ;
		krb5_keytab keytab = NULL;
		krb5_get_init_creds_opt options;
		krb5_creds creds;

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
		code = krb5_cc_default(context, &ccache);
		if(code)
		{
			krb_error_while_doing = "could not get default ccache";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}
		code = krb5_parse_name(context, principle, &princ);
		if(code)
		{
			krb_error_while_doing = "could not parse principle name";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}

		krb5_get_init_creds_opt_init(&options);
		memset(&creds, 0, sizeof(creds));
		krb5_get_init_creds_opt_set_forwardable(&options, 0);
		krb5_get_init_creds_opt_set_proxiable(&options, 0);

		code = krb5_kt_resolve(context, keytab_name, &keytab);
		if(code != 0)
		{
			krb_error_while_doing = "could not resolve keytab";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}

		code = krb5_get_init_creds_keytab(context, &creds, princ, keytab, 0, NULL, &options);
		if(code)
		{
			krb_error_while_doing = "could not get initial credentials";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}

		krb_expires = creds.times.endtime;

		code = krb5_cc_initialize(context, ccache, princ);
		if(code)
		{
			krb_error_while_doing = "could not initialize cache";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}
		code = krb5_cc_store_cred(context, ccache, &creds);
		if(code)
		{
			krb_error_while_doing = "could not store credentials";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}

		krb5_free_cred_contents(context, &creds);
		krb5_kt_close(context, keytab);

#		/* clean up*/
		krb5_free_principal(context, princ);
		krb5_cc_close(context, ccache);
		krb5_free_context(context);

#		/*atexit(kdestroy_atexit);*/
		RETVAL=1;
	OUTPUT:
		RETVAL

#/* equivilent to calling kdestory */

int
kdestroy()
#	/* returns
#	 * 	0	- success
#	 * 	other	- krb5 error code
#	 */
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
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}
		code = krb5_cc_destroy(context, ccache);
		if(code)
		{
			krb_error_while_doing = "unable to destroy ccache";
			krb_error_string = (char *)error_message(code);
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
#	/* return:
#	 * 	0	- error
#	 * 	other	- time of experation
#	 */
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
			XSRETURN_UNDEF;
		}
		code = krb5_cc_default(context, &ccache);
		if(code)
		{
			krb_error_while_doing = "could not get default ccache";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}
		flags = 0;
		code = krb5_cc_set_flags(context, ccache, flags);
		if(code)
		{
			krb_error_while_doing = "could not set ccache flags";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}
		code = krb5_cc_get_principal(context, ccache, &princ);
		if(code)
		{
			krb_error_while_doing = "could not get principle";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}
		code = krb5_cc_start_seq_get(context, ccache, &current);
		if(code)
		{
			krb_error_while_doing = "could not start sequential get";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
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
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}
		code = krb5_cc_end_seq_get(context, ccache, &current);
		if(code)
		{
			krb_error_while_doing = "could not finish reading credentials";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}
		flags = KRB5_TC_OPENCLOSE;
		code = krb5_cc_set_flags(context, ccache, flags);
		if(code)
		{
			krb_error_while_doing = "could not set ccache flags";
			krb_error_string = (char *)error_message(code);
			krb_error_code = code;
			XSRETURN_UNDEF;
		}
		krb5_cc_close(context, ccache);
		krb5_free_context(context);
		RETVAL=earliest;
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

char *
get_error_string()
	CODE:
		RETVAL = krb_error_string;
	OUTPUT:
		RETVAL

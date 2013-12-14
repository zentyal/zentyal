/*
   Retrieve summary list of contacts

   OpenChange Project

   Copyright (C) Julien Kerihuel 2013

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "libmapi/libmapi.h"
#include "libmapi/mapi_nameid.h"
#include <inttypes.h>
#include <stdlib.h>
#include <popt.h>

#define	DEFAULT_PROFDB	"%s/.openchange/profiles.ldb"

extern struct poptOption popt_openchange_version[];
#define	POPT_OPENCHANGE_VERSION { NULL, 0, POPT_ARG_INCLUDE_TABLE, popt_openchange_version, 0, "Common openchange options:", NULL },

static void popt_openchange_version_callback(poptContext con,
					     enum poptCallbackReason reason,
					     const struct poptOption *opt,
					     const char *arg,
					     const void *data)
{
	switch (opt->val) {
	case 'V':
		printf("Version %s\n", OPENCHANGE_VERSION_STRING);
		exit (0);
	}
}

struct poptOption popt_openchange_version[] = {
	{ NULL, '\0', POPT_ARG_CALLBACK, (void *)popt_openchange_version_callback, '\0', NULL, NULL },
	{ "version", 'V', POPT_ARG_NONE, NULL, 'V', "Print version ", NULL },
	POPT_TABLEEND
};


static enum MAPISTATUS contact_summary(TALLOC_CTX *mem_ctx,
				       mapi_object_t *obj_store)
{
	enum MAPISTATUS		retval = MAPI_E_SUCCESS;
	mapi_object_t		obj_folder;
	mapi_id_t		id_contact;

	mapi_object_t		obj_ctable;
	mapi_object_t		obj_atable;
	mapi_object_t		obj_msg;
	struct SPropTagArray	*SPropTagArray;
	struct SRowSet		rowset;
	struct SRow		aRow;
	struct SRowSet		arowset;
	uint64_t		*fid;
	uint64_t		*msgid;
	const char		*displayname;
	const char		*givenname;
	const char		*company;
	const char		*email;
	uint32_t		index;
	uint32_t		aindex;

	mapi_object_init(&obj_folder);

	retval = GetDefaultFolder(obj_store, &id_contact, olFolderContacts);
	if (retval != MAPI_E_SUCCESS) return retval;

	retval = OpenFolder(obj_store, id_contact, &obj_folder);
	MAPI_RETVAL_IF(retval, retval, NULL);

	mapi_object_init(&obj_ctable);
	retval = GetContentsTable(&obj_folder, &obj_ctable, 0, NULL);
	MAPI_RETVAL_IF(retval, retval, NULL);

	SPropTagArray = set_SPropTagArray(mem_ctx, 6,
					  PidTagFolderId,
					  PidTagMid,
					  PidTagEmailAddress,
					  PidTagCompanyName,
					  PidTagDisplayName,
					  PidTagGivenName);
	retval = SetColumns(&obj_ctable, SPropTagArray);
	if (retval) {
		mapi_object_release(&obj_ctable);
		mapi_object_release(&obj_folder);
		MAPIFreeBuffer(SPropTagArray);
		return retval;
	}
	MAPIFreeBuffer(SPropTagArray);

	while (((retval = QueryRows(&obj_ctable, 0x32, TBL_ADVANCE, &rowset)) != MAPI_E_NOT_FOUND) 
	       && rowset.cRows) {
		for (index = 0; index < rowset.cRows; index++) {
			aRow = rowset.aRow[index];
			fid = (uint64_t *) find_SPropValue_data(&aRow, PidTagFolderId);
			msgid = (uint64_t *) find_SPropValue_data(&aRow, PidTagMid);
			displayname = (const char *) find_SPropValue_data(&aRow, PidTagDisplayName);
			givenname = (const char *) find_SPropValue_data(&aRow, PidTagGivenName);
			company = (const char *) find_SPropValue_data(&aRow, PidTagCompanyName);
			email = (const char *) find_SPropValue_data(&aRow, PidTagEmailAddress);

			DEBUG(0, ("[+] Contact: %s, %s [email=<%s>][company=%s]\n", 
				  displayname?displayname:"", givenname?givenname:"", 
				  email?email:"None", company?company:"None"));
		}
	}
	mapi_object_release(&obj_ctable);
	mapi_object_release(&obj_folder);
	return MAPI_E_SUCCESS;
}


int main(int argc, const char *argv[])
{
	TALLOC_CTX		*mem_ctx;
	enum MAPISTATUS		retval;
	struct mapi_session	*session = NULL;
	struct mapi_context	*mapi_ctx;
	mapi_object_t		obj_store;
	poptContext		pc;
	int			opt;
	bool			opt_dumpdata = false;
	const char		*opt_debug = NULL;
	const char		*opt_profdb = NULL;
	char			*opt_profname = NULL;
	const char		*opt_password = NULL;
	const char		*opt_username = NULL;

	enum {OPT_PROFILE_DB=1000, OPT_PROFILE, OPT_PASSWORD, OPT_USERNAME, OPT_DEBUG, OPT_DUMPDATA };

	struct poptOption long_options[] = {
		POPT_AUTOHELP
		{"database", 'f', POPT_ARG_STRING, NULL, OPT_PROFILE_DB, "set the profile database path", NULL },
		{"profile", 'p', POPT_ARG_STRING, NULL, OPT_PROFILE, "set the profile name", NULL },
		{"password", 'P', POPT_ARG_STRING, NULL, OPT_PASSWORD, "set the profile password", NULL },
		{"username", 'U', POPT_ARG_STRING, NULL, OPT_USERNAME, "specify the user's mailbox to calculate", NULL },
		{"debuglevel", 'd', POPT_ARG_STRING, NULL, OPT_DEBUG, "set the debug level", NULL },
		{"dump-data", 0, POPT_ARG_NONE, NULL, OPT_DUMPDATA, "dump the hexadecimal and NDR data", NULL },
		POPT_OPENCHANGE_VERSION
		{NULL, 0, 0, NULL, 0, NULL, NULL}
	};

	mem_ctx = talloc_named(NULL, 0, "mailboxsize");
	if (mem_ctx == NULL) {
		DEBUG(0, ("[!] Not enough memory\n"));
		exit(1);
	}

	pc = poptGetContext("mailboxsize", argc, argv, long_options, 0);
	while ((opt = poptGetNextOpt(pc)) != -1) {
		switch (opt) {
		case OPT_DEBUG:
			opt_debug = poptGetOptArg(pc);
			break;
		case OPT_DUMPDATA:
			opt_dumpdata = true;
			break;
		case OPT_PROFILE_DB:
			opt_profdb = poptGetOptArg(pc);
			break;
		case OPT_PROFILE:
			opt_profname = talloc_strdup(mem_ctx, poptGetOptArg(pc));
			break;
		case OPT_PASSWORD:
			opt_password = poptGetOptArg(pc);
			break;
		case OPT_USERNAME:
			opt_username = poptGetOptArg(pc);
			break;
		default:
			DEBUG(0, ("[!] Non-existent option\n"));
			exit (1);
		}
	}

	/* Sanity check on options */
	if (!opt_profdb) {
		opt_profdb = talloc_asprintf(mem_ctx, DEFAULT_PROFDB, getenv("HOME"));
	}

	/* Step 1. Initialize MAPI subsystem */
	retval = MAPIInitialize(&mapi_ctx, opt_profdb);
	if (retval != MAPI_E_SUCCESS) {
		mapi_errstr("[!] MAPIInitialize", GetLastError());
		exit (1);
	}

	/* Step 2. Set debug options */
	SetMAPIDumpData(mapi_ctx, opt_dumpdata);
	if (opt_debug) {
		SetMAPIDebugLevel(mapi_ctx, atoi(opt_debug));
	}

	/* Step 3. Profile loading */
	if (!opt_profname) {
		retval = GetDefaultProfile(mapi_ctx, &opt_profname);
		if (retval != MAPI_E_SUCCESS) {
			mapi_errstr("[!] GetDefaultProfile", GetLastError());
			exit (1);
		}
	}

	/* Step 4. Logon into EMSMDB pipe */
	retval = MapiLogonProvider(mapi_ctx, &session,
				   opt_profname, opt_password,
				   PROVIDER_ID_EMSMDB);
	if (retval != MAPI_E_SUCCESS) {
		mapi_errstr("[!] MapiLogonProvider", GetLastError());
		exit (1);
	}
		
	/* Step 5. Open Default Message Store */
	mapi_object_init(&obj_store);
	if (opt_username) {
		retval = OpenUserMailbox(session, opt_username, &obj_store);
		if (retval != MAPI_E_SUCCESS) {
			mapi_errstr("[!] OpenUserMailbox", GetLastError());
			exit (1);
		}
	} else {
		retval = OpenMsgStore(session, &obj_store);
		if (retval != MAPI_E_SUCCESS) {
			mapi_errstr("[!] OpenMsgStore", GetLastError());
			exit (1);
		}
	}

	/* Step 6. Calculation task and print */
	retval = contact_summary(mem_ctx, &obj_store);
	if (retval) {
		mapi_errstr("mailbox", GetLastError());
		exit (1);
	}

	poptFreeContext(pc);
	mapi_object_release(&obj_store);
	MAPIUninitialize(mapi_ctx);
	talloc_free(mem_ctx);

	return 0;
}

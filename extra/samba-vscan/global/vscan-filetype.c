/* $Id: vscan-filetype.c,v 1.3 2003/09/04 09:06:26 reniar Exp $ 
 *
 * Determines the file type by using libmagic. Used to skip scanning of
 * certain file types (user setting)
 *
 * Copyright (c) Rainer Link, 2003
 *	         OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * This module is used to detected the MIME-type of a file by using 
 * libmagic. It then decided whether a file must be scanned or not
 * depending on the exclude file type setting.
 *
 * 			THIS IS WORK-IN-PROGRESS!
 *
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/  

#include "vscan-global.h"
#include "magic.h"


/* pointer to magic :-) */
static magic_t filetype_magic = NULL;

/* contains the list of MIME-types which files should be excluded
   from scanning */
static pstring filetype_excludelist = "";

/* indicates whether init libmagic was successfull or not */
static BOOL filetype_init_magic = False;

/** 
 * initialise libmagic and load magic
 * @params flags	flags for libmagic, see man libmagic
 *
*/

BOOL filetype_init (int flags, pstring exclude_list) {

	pstrcat(filetype_excludelist, exclude_list);
	trim_string(filetype_excludelist, " ", " ");
	
	if ( strlen(filetype_excludelist) > 0 ) {
		DEBUG(1, ("exclude list is: '%s'\n", filetype_excludelist)); 
		
		/* initialise libmagic */
		DEBUG(1, ("initialise libmagic\n"));
	
		flags |= MAGIC_MIME;
		DEBUG(1, ("magic flags: %d\n", flags));

		filetype_magic = magic_open(flags);
		if ( filetype_magic == NULL ) {
			/* FIXME: probably we shouln't use vscan_syslog here */
				vscan_syslog("could not initialise libmagic");
		} else {
			DEBUG(1, ("loading magic\n"));
			/* NULL = load default file, probably we need another user setting here to specifiy alternative magic files */
			if ( magic_load(filetype_magic, NULL) != 0 ) {	/* error */
				vscan_syslog("%s", magic_error(filetype_magic));
			} else {
				DEBUG(1, ("libmagic init and loading was successfull\n"));
				filetype_init_magic = True;
			} /* end if */
		} /* end if */		
	} else {
		DEBUG(1, ("exclude list is empty - nothing to do\n"));	
	} /* end if */

	return filetype_init_magic;

} /* end function */

/**
 * closes libmagic
 * 
*/

void filetype_close() {
	
	if ( filetype_init_magic )
		magic_close(filetype_magic);

}


/**
 * determins whether scan of file should be skipped or not 
 *
 * @param fname		file name
 * @return
 *	-1		error occured; file must be scanned
 *	 0		file type not in list, file must be scanned
 *	 1		file type in exclude list, skip file, i.e. do not
 *			scan file
 *
*/

int filetype_skipscan(pstring fname) {

		/* as next_token modifies input */
		pstring ex_list;
		pstring exclude;
		const char* p; /* needed to avoid compiler warning */
		pstring filetype_string;


		if ( !filetype_init_magic ) {
			DEBUG(1, ("libmagic init has failed or exclude list is empty - feature disabled\n"));
			return -1;
		}
		
		/* get the file type */
		pstrcpy(filetype_string, magic_file(filetype_magic, fname));
		if ( filetype_string == NULL ) {  /* error */
			vscan_syslog("could not get file type, %s", magic_error(filetype_magic));
			/* error occured */
			return -1;
		} /* end if */ 
		trim_string(filetype_string, " ", " ");
		DEBUG(1, ("file type of file %s is %s\n", fname, filetype_string));	

		/* next_token modifies input list, so copy it */
		pstrcpy(ex_list, filetype_excludelist);

		/* to avoid compiler warnings */
		p = ex_list;

		while ( next_token(&p, exclude, ";", sizeof(exclude)) ) {
			trim_string(exclude, " ", " ");
			DEBUG(1, ("current exclude type is: '%s'\n", exclude));
			if ( StrCaseCmp(exclude, filetype_string) == 0 ) {
				/* file type is in exlude list */
				DEBUG(1, ("file type '%s' is in exclude list\n", exclude));
				/* advise to skip scanning of file */
				return 1;
			} /* end if */
		} /* end while */

		/* file must be scanned */
		DEBUG(1, ("no match - file must be scanned\n"));
		return 0;
}
	


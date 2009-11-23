/* $Id: vscan-fileregexp.c,v 1.1.2.2 2005/04/08 09:06:31 reniar Exp $ 
 *
 * Used to skip scanning of certain files (by name and/or path) (user setting)
 *
 * Copyright (c) Rainer Link, 2005
 *	         OpenAntiVirus.org <rainer@openantivirus.org>
 * Copyright (c) Sven Strickroth, 2005
 *	         <email@cs-ware.de>
 * thanks to the pcredemo-program
 *
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/  

/* FIXME: when module works correctly, increase value of DEBUG statements */

#include "vscan-global.h"

#ifdef HAVE_FILEREGEXP_SUPPORT

#include <pcre.h>

#define OVECCOUNT 30    /* should be a multiple of 3 */

static pstring fileregexp_excludepattern = "";

BOOL fileregexp_init (pstring filetype_excluderegexp) {

	//trim_string(filetype_excluderegexp, " ", " ");
	
	if ( strlen(filetype_excluderegexp) > 0 ) {

		DEBUG(5, ("exclude regexp is: '%s'\n", filetype_excluderegexp)); 
		pstrcpy(fileregexp_excludepattern, filetype_excluderegexp);

	} else {
		DEBUG(5, ("exclude regexp is empty - nothing to do\n"));	
	} /* end if */

	return True;

} /* end function */

/**
 * determins whether scan of file should be skipped or not 
 *
 * @param fname		file name
 * @return
 *	-1		error occured; file must be scanned
 *	 0		file not in list, file must be scanned
 *	 1		file in exclude regexp, skip file, i.e. do not
 *			scan file
 *
*/

int fileregexp_skipscan(pstring fname) {
		if (strlen(fileregexp_excludepattern) > 0) {
			int ovector[OVECCOUNT];
			int rc;
			pcre *exclude_re = NULL;
			const char *error;
			int erroffset;


			exclude_re = pcre_compile(
			  fileregexp_excludepattern, /* the pattern */
			  0,                      /* default options */
			  &error,                 /* for error message */
			  &erroffset,             /* for error offset */
			  NULL);                  /* use default character tables */
	
			if (exclude_re == NULL) {
				DEBUG(0,("PCRE compilation failed at offset %d: %s\n", erroffset, error));
				return VSCAN_FR_ERROR_MUST_SCAN;
			}


			rc = pcre_exec(
			  exclude_re,                   /* the compiled pattern */
			  NULL,                 /* no extra data - we didn't study the pattern */
			  fname,              /* the subject string */
			  strlen(fname),       /* the length of the subject */
			  0,                    /* start at offset 0 in the subject */
			  0,                    /* default options */
			  ovector,              /* output vector for substring information */
			  OVECCOUNT);           /* number of elements in the output vector */

			/* Matching failed: handle error cases */
			
			if ( rc < 0 ) {
			  switch(rc) {
			    case PCRE_ERROR_NOMATCH: 
				DEBUG(5,("No match\n")); 
				SAFE_FREE(exclude_re);
				return VSCAN_FR_MUST_SCAN; 
				break;
			    /*
			    Handle other special cases if you like
			    */
			    default: 
				DEBUG(5,("Matching error %d\n", rc)); 
				SAFE_FREE(exclude_re);
				return VSCAN_FR_ERROR_MUST_SCAN; 
				break;
			    }
		  	}
		
			/* Match succeded */
			SAFE_FREE(exclude_re);
			DEBUG(5,("matched!\n"));
			return VSCAN_FR_SKIP_SCAN;
		} /* end if */

		DEBUG(5,("no pattern\n"));
		return VSCAN_FR_MUST_SCAN;
}

#else /* HAVE_FILEREGEXP_SUPPORT */

BOOL fileregexp_init (pstring filetype_excluderegexp)
{
	DEBUG(5,("Sorry, samba-vscan regexp-exclude support is not compiled in\n"));
	return True;
}

int fileregexp_skipscan(pstring fname)
{
	DEBUG(10,("Sorry, samba-vscan regexp-exclude support is not compiled in\n"));	
	return 0;
}
#endif


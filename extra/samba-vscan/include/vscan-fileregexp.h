#ifndef __VSCAN_FILEREGEXP_H_
#define __VSCAN_FILEREGEXP_H_


/* actions */

/* error occured; file must be scanned */
#define VSCAN_FR_ERROR_MUST_SCAN	-1
/* file not in list, file must be scanned */
#define VSCAN_FR_MUST_SCAN 		 0
/* file in exclude regexp, skip file, 
   i.e. do not scan file */
#define VSCAN_FR_SKIP_SCAN 		 1


bool fileregexp_init (pstring filetype_excluderegexp);
void fileregexp_close(void);
int fileregexp_skipscan(pstring fname);

#endif /* __VSCAN_FILEREGEXP_H_ */

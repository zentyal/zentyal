#ifndef __VSCAN_FILETYPE_H_
#define __VSCAN_FILETYPE_H_


/* actions */

/* error occured; file must be scanned */
#define VSCAN_FT_ERROR_MUST_SCAN	-1
/* file type not in list, file must be scanned */
#define VSCAN_FT_MUST_SCAN 		 0
/* file type in exclude list, skip file, 
   i.e. do not scan file */
#define VSCAN_FT_SKIP_SCAN 		 1


BOOL filetype_init (int flags, pstring exclude_list);
void filetype_close(void);
int filetype_skipscan(pstring fname);

#endif /* __VSCAN_FILETYPE_H_ */

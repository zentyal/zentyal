#ifndef __ZAVS_FILEREGEXP_H_
#define __ZAVS_FILEREGEXP_H_

// Error occured; file must be scanned
#define ZAVS_FR_ERROR_MUST_SCAN	-1

// File not in list; file must be scanned
#define ZAVS_FR_MUST_SCAN 		 0

// File in exclude regexp; do not scan file
#define ZAVS_FR_SKIP_SCAN 		 1

bool fileregexp_init(const char *exclude_regexp);
void fileregexp_close(void);
int fileregexp_skipscan(const char *fname);

#endif /* __ZAVS_FILEREGEXP_H_ */

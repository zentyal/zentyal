#ifndef __ZAVS_FILETYPE_H_
#define __ZAVS_FILETYPE_H_

#include <stdbool.h>

// Error occured; file must be scanned
#define ZAVS_FT_ERROR_MUST_SCAN    -1

// File type not in list; file must be scanned
#define ZAVS_FT_MUST_SCAN          0

// File type in exclude list; do not scan file
#define ZAVS_FT_SKIP_SCAN          1

bool filetype_init (int flags, const char *exclude_list);
void filetype_close(void);
//int filetype_skipscan(const char *fname);

#endif /* __ZAVS_FILETYPE_H_ */

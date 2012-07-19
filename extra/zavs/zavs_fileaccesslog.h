#ifndef __ZAVS_FILEACCESSLOG_H_
#define __ZAVS_FILEACCESSLOG_H_

#include <time.h>
#include <stdbool.h>

/* file needs to be scanned */
#define ZAVS_LRU_SCAN_FILE     1
/* deny access to file */
#define ZAVS_LRU_DENY_ACCESS  -1
/* grant access without scanning */
#define ZAVS_LRU_GRANT_ACCESS  0


struct lrufiles_struct {
    struct lrufiles_struct *prev, *next;
    char fname[1024];   /* the file name */
    time_t mtime;       /* mtime of file */
    bool infected;      /* infected? */
    time_t time_added;  /* time entry was added to list */
};

void lrufiles_init(int max_enties, time_t invalidate_time);
//struct lrufiles_struct *lrufiles_add(pstring fname, time_t mtime, bool infected);
void lrufiles_destroy_all(void);
//struct lrufiles_struct *lrufiles_search(pstring fname);
//void lrufiles_delete(pstring fname);
//int lrufiles_must_be_checked (pstring fname, time_t mtime);

#endif /* __ZAVS_FILEACCESSLOG_H_ */

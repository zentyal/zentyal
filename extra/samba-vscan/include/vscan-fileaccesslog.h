#ifndef __VSCAN_FILEACCESSLOG_H_
#define __VSCAN_FILEACCESSLOG_H_

/* maximum number of entries */
#define MAX_LRUFILES 100
/* invalidate entry after x seconds */
#define LRUFILES_INVALIDATE_TIME 10  


/* actions to be performed */

/* file needs to be scanned */
#define VSCAN_LRU_SCAN_FILE     1
/* deny access to file */
#define VSCAN_LRU_DENY_ACCESS  -1
/* grant access without scanning */
#define VSCAN_LRU_GRANT_ACCESS  0


struct lrufiles_struct {
	struct lrufiles_struct *prev, *next;
	pstring fname;		/* the file name */
	time_t mtime;		/* mtime of file */
	BOOL infected;		/* infected? */
	time_t time_added;	/* time entry was added to list */
};
void lrufiles_init(int max_enties, time_t invalidate_time);
struct lrufiles_struct *lrufiles_add(pstring fname, time_t mtime, BOOL infected);
void lrufiles_destroy_all(void);
struct lrufiles_struct *lrufiles_search(pstring fname);
void lrufiles_delete(pstring fname);
int lrufiles_must_be_checked (pstring fname, time_t mtime);

#endif /* __VSCAN_FILEACCESSLOG_H_ */

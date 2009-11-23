#ifndef __VSCAN_FILEACCESSLOG_H_
#define __VSCAN_FILEACCESSLOG_H_

#define MAX_LRUFILES 100
#define LRUFILES_INVALIDATE_TIME 10  

struct lrufiles_struct {
	struct lrufiles_struct *prev, *next;
	pstring fname;		/* the file name */
	time_t mtime;		/* mtime of file */
	bool infected;		/* infected? */
	time_t time_added;	/* time entry was added to list */
};
void lrufiles_init(int max_enties, time_t invalidate_time);
struct lrufiles_struct *lrufiles_add(pstring fname, time_t mtime, bool infected);
void lrufiles_destroy_all(void);
struct lrufiles_struct *lrufiles_search(pstring fname);
void lrufiles_delete(pstring fname);
int lrufiles_must_be_checked (pstring fname, time_t mtime);

#endif /* __VSCAN_FILEACCESSLOG_H_ */

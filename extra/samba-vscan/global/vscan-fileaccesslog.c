/* $Id: vscan-fileaccesslog.c,v 1.8.2.5 2007/05/19 17:59:42 reniar Exp $
 * 
 * File Access Log - stores information about LRU files
 *
 * Copyright (C) Rainer Link, 2002-2003
 *	 	 OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * This module is used to detect whether Windows opens the same file
 * again and again several times (in a very short time of period), i.e.
 * when double-clicking a file. So, i.e. if you click on an infected
 * word file, Windows tries to open it several times until it reports
 * the "Access denied" back to the user.
 * 
 * It uses some kind of last recently used machanism, so the most LRU
 * file is stored at the end of a doubled-linked list. So, new entries
 * are added at the end of the list, but also the search function moves a
 * found entry to the end of the list.
 *
 * An entry stores information about the file name, the modify time (mtime),
 * a flag indicates if a file is marked as infected or not and the time
 * the entry was created. 
 * 
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/

#include "vscan-global.h"

/* pointer to the first entry of list */
static struct lrufiles_struct *Lrufiles = NULL;
/* pointer to the last entry of list */
static struct lrufiles_struct *LrufilesEnd = NULL;

/* counter for entries in list */ 
static int lrufiles_count = 0;
static int lrufiles_max_entries = MAX_LRUFILES;
static time_t lrufiles_invalidate_time = LRUFILES_INVALIDATE_TIME;


/** Delete an entry from the lrufile list given by pointer. The
 * entry must be in the list (this is not checked).
 * @param entry The entry to be deleted
 */
static void lrufiles_delete_p(struct lrufiles_struct *entry)
{
	DEBUG(10, ("removing entry from lrufiles list: '%s'\n",
			entry->fname));
	/* should the last entry be deleted? If yes, set LrufilesEnd pointer */
	if ( LrufilesEnd == entry )
		LrufilesEnd = entry->prev;
	DLIST_REMOVE(Lrufiles, entry);
	ZERO_STRUCTP(entry);
	SAFE_FREE(entry);
	lrufiles_count--;
	DEBUG(10, ("entry deleted, %d left in list\n", lrufiles_count));

}

/** 
 * initialise the double-linked list 
 * @param max_entries		specifies the maximum number of entries, if 0
 *				the lru file access feature is disabled completly!!!
 * @param invalidate_time	specifies the life time of an entry in seconds
 *
*/  

void lrufiles_init(int max_entries, time_t invalidate_time) {
	
	/* hum, better safe than sorry? */
	DEBUG(10, ("initialise lrufiles\n"));
	ZERO_STRUCTP(Lrufiles);
	Lrufiles = NULL;
	ZERO_STRUCTP(LrufilesEnd);
	LrufilesEnd = NULL;
	lrufiles_count = 0;
	/* NOTE: if max_entries == 0, the lru files access feature is disabled
	   completely! */
	lrufiles_max_entries = max_entries;

	lrufiles_invalidate_time = invalidate_time;

	DEBUG(10, ("initilising lrufiles finished\n"));
}


/**
 * Search an entry as specified via file name. If found, moved entry
 * to the end of the list, too
 * @param fname file name
 * @return a pointer to the found entry or NULL
 *
*/
struct lrufiles_struct *lrufiles_search(pstring fname) {
        struct lrufiles_struct *curr, *tmp = NULL;

	DEBUG(10, ("search for '%s' in lrufiles\n", fname));
        /* search backwards */
        curr = LrufilesEnd;
        while ( curr != NULL ) {
                if ( StrCaseCmp(fname, curr->fname) == 0 ) {
			DEBUG(10, ("file '%s' matched\n", fname));
                        /* match ... */
                        /* move to end of list */
                        DLIST_REMOVE(Lrufiles, curr);
			#if (SMB_VFS_INTERFACE_VERSION >= 21)
			 DLIST_ADD_END(Lrufiles, curr, struct lrufiles_struct *);
			#else
                         DLIST_ADD_END(Lrufiles, curr, tmp);
			#endif
                        LrufilesEnd = curr;
                        /* return it */
                        return curr;
                }
                curr = curr->prev;
        }

        /* not found */
	DEBUG(10, ("file '%s' not matched\n", fname));
        return NULL;
}


/** 
 * Adds a new entry, or if the entry already exists, mtime and infected values
 * are updated
 * @param fname the file name
 * @param mtime time the file was last modified
 * @param infected marks a file as infected or not infected
 * @return returns a pointer of the new entry, the updated entry or NULL
 *	   if no memory could be allocated
 *
*/
struct lrufiles_struct *lrufiles_add(pstring fname, time_t mtime, BOOL infected) {
	struct lrufiles_struct *new_entry, *tmp, *found = NULL;

	/* check if lru file access was disabled by setting the corresponding
	   value in the configuration file to zero (or below zero) */
	if ( lrufiles_max_entries <= 0 ) {
		DEBUG(1, ("lru files feature is disabled, do nothing\n"));
		/* do nothing, simply return NULL */
		return NULL;
	}
	DEBUG(10, ("file '%s' should be added\n", fname));
	/* check if file has already been added */
	found = lrufiles_search(fname);
	if ( found != NULL ) {
		/* has already been added, update mtime and infected only */
		DEBUG(10, ("file '%s' in list, update mtime and infected\n", fname));
		found->mtime = mtime;
		found->infected = infected;
		/* FIXME hm, should we updated it or not?! */
		/* found->time_added = time(NULL); */
		return found;
	} else {
		DEBUG(10, ("alloc space for file entry '%s'\n", fname));
		new_entry = (struct lrufiles_struct *)malloc(sizeof(*new_entry));
		if (!new_entry) return NULL;

		ZERO_STRUCTP(new_entry);

		pstrcpy(new_entry->fname, fname);
		new_entry->mtime = mtime;
		new_entry->infected = infected;
		new_entry->time_added = time(NULL);

		/* reached maximum? */
		if ( lrufiles_count == lrufiles_max_entries ) {
			DEBUG(10, ("lru maximum reached '%d'\n", lrufiles_count));
			/* remove the first one - it really removes only the first one */
			tmp = Lrufiles;
			DEBUG(10, ("removing first entry..."));
			lrufiles_delete_p(tmp);
		}
		
		DEBUG(10, ("adding new entry to list...\n"));
		#if (SMB_VFS_INTERFACE_VERSION >= 21)
 		 DLIST_ADD_END(Lrufiles, new_entry, struct lrufiles_struct *);
		#else
		 DLIST_ADD_END(Lrufiles, new_entry, tmp);
		#endif
		LrufilesEnd = new_entry;
		lrufiles_count++;
		DEBUG(10, ("entry '%s' added, count '%d'\n", fname, lrufiles_count));

		return new_entry;
	}
}

/**
 * List is beeing destroyed and all entries freed
 *
*/
void lrufiles_destroy_all() {
	struct lrufiles_struct *tmp, *curr;

	/* check if lru file access was disabled by setting the corresponding
	   value in the configuration file to zero (or below zero) */
	if ( lrufiles_max_entries <= 0 ) {
		DEBUG(10, ("lru files feature is disabled, do nothing\n"));
		/* do nothing, simply return */
		return;
	}

	DEBUG(10, ("destroy lrufiles\n"));
	curr = Lrufiles;
	while (curr != NULL) {
		tmp = curr;
		curr = curr->next;
		DLIST_REMOVE(Lrufiles, tmp);
		ZERO_STRUCTP(tmp);
		SAFE_FREE(tmp);
	}
	Lrufiles = NULL;
	LrufilesEnd = NULL;
	lrufiles_count = 0;
	DEBUG(10, ("lrufiles destroyed\n"));
}


/** 
 * Deletes an entry in the list as specified via fname
 * @param fname the file name
 *
*/
void lrufiles_delete(pstring fname) {
	struct lrufiles_struct *found = NULL;

	/* check if lru file access was disabled by setting the corresponding
	   value in the configuration file to zero (or below zero) */
	if ( lrufiles_max_entries <= 0 ) {
		DEBUG(10, ("lru files feature is disabled, do nothing\n"));
		/* do nothing, simply return NULL */
		return; 
	}

	DEBUG(10, ("file entry '%s' should be deleted\n", fname));
	found = lrufiles_search(fname);
	if ( found != NULL ) 
		lrufiles_delete_p(found);
}
			

/**
 * This method is used to detect whether a file must be scanned, it must not
 * be scanned but access denied (as file is marked as infected) or if it
 * must not be scanned and access granted.
 * @param fname the file name
 * @param mtime the time file was last modified
 * @return
 * 	-1 - file is in list and marked as infected
 * 	 0 - file is in list, not marked as infected and not modified
 *	 1 - file is in list, not marked as infected but modified _OR_
 *           file is not in list _OR_ lru file access feature is disabled
 *
*/
int lrufiles_must_be_checked (pstring fname, time_t mtime) {
	struct lrufiles_struct *found = NULL;

	/* check if lru file access was disabled by setting the corresponding
	   value in the configuration file to zero (or below zero) */
	if ( lrufiles_max_entries <= 0 ) {
		DEBUG(10, ("lru files feature is disabled, do nothing\n"));
		/* do nothing, simply return 1 to advise scanning of file */
		return VSCAN_LRU_SCAN_FILE;
	}

	DEBUG(10, ("lookup '%s'\n", fname));
	/* lookup the entry */
	found = lrufiles_search(fname);
	if (found == NULL ) {
		/* not found */ 
		DEBUG(10, ("entry '%s' not found\n", fname));
		/* file must be scanned */
		return VSCAN_LRU_SCAN_FILE;
	} else {
		if ( found->time_added > time(NULL) ) {
			/* uhm, someone has changed the clock?!? */
			/* delete entry and advise to scan file */
			DEBUG(10, ("Clock has changed. Invalidate '%s'\n", found->fname));
			lrufiles_delete_p(found);
			/* file must be scanned */
			return VSCAN_LRU_SCAN_FILE;
		} else if ( time(NULL) >= (found->time_added + lrufiles_invalidate_time) ) {
			/* lifetime expired */
			/* remove entry, advide to scan */
                        DEBUG(10, ("Lifetime expired. Invalidate '%s'\n", found->fname));
			lrufiles_delete_p(found);
			/* file must be scanned */
			return VSCAN_LRU_SCAN_FILE;
		} else {
			if ( found->mtime == mtime ) {
				/* found, not modified */
				DEBUG(10, ("entry '%s' found, file was not modified\n", fname));
				if ( found->infected ) {
					DEBUG(10, ("entry '%s' marked as infected\n", fname));
					/* file mark as infected, access must be denied */
					return VSCAN_LRU_DENY_ACCESS;
				} else {
					DEBUG(10, ("entry '%s' marked as not infected\n", fname));
					/* ok, it's safe to grant access without virus scan */
					return VSCAN_LRU_GRANT_ACCESS;
				}
			} else {
				/* found, was modified */
				DEBUG(10, ("entry '%s' found, file was modified\n", fname));
				/* file was modified, it must be scanned */
				return VSCAN_LRU_SCAN_FILE;
			}
		}
	}
	/* shouln't get there - but to be safe file must be scanned */
	return VSCAN_LRU_SCAN_FILE;
}

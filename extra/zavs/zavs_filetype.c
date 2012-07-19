#include <includes.h>

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <magic.h>

#include "zavs_log.h"

// Pointer to magic :-)
static magic_t filetype_magic = NULL;

// Contains the list of MIME-types which files should be excluded from scanning
static char filetype_excludelist[1024] = "";

// Indicates whether init libmagic was successfull or not
static bool filetype_init_magic = false;

/**
 *
 * Initialise libmagic and load magic
 *
 * @param flags - flags for libmagic, see man libmagic
 * @param exclude_list - list of file types to exclude
 *
 */
bool filetype_init (int flags, const char *exclude_list)
{
    // Clear buffer
    memset(filetype_excludelist, 0, sizeof(filetype_excludelist));
    // Copy the exclude list and trim, let one byte at the end as '\0' for safety
    strncpy(filetype_excludelist, exclude_list,
            sizeof(filetype_excludelist) - 1);
    trim_string(filetype_excludelist, " ", " ");

    // Init library
    if (strnlen(filetype_excludelist, sizeof(filetype_excludelist)) > 0) {
        ZAVS_DEBUG(5, "exclude list is: '%s'\n", filetype_excludelist);
        ZAVS_DEBUG(5, "initialise libmagic\n");

        flags |= MAGIC_MIME;
        ZAVS_DEBUG(5, "magic flags: %d\n", flags);

        filetype_magic = magic_open(flags);
        if ( filetype_magic == NULL ) {
            ZAVS_ERROR("could not initialise libmagic");
        } else {
            ZAVS_DEBUG(5, "loading magic\n");
            // NULL = load default file, probably we need another user
            // setting here to specifiy alternative magic files
            if (magic_load(filetype_magic, NULL) != 0) {
                ZAVS_ERROR("couldn't load magic: %s", magic_error(filetype_magic));
            } else {
                ZAVS_DEBUG(5, "libmagic init and loading was successfull\n");
                filetype_init_magic = true;
            }
        }
    } else {
        ZAVS_DEBUG(5, "exclude list is empty - nothing to do\n");
    }

    return filetype_init_magic;
}


/**
 *
 * Closes libmagic
 *
 */
void filetype_close(void)
{
    if (filetype_init_magic) {
        magic_close(filetype_magic);
        filetype_init_magic = false;
    }
}


///**
// * determins whether scan of file should be skipped or not
// *
// * @param fnamefile name
// * @return
// *-1error occured; file must be scanned
// * 0file type not in list, file must be scanned
// * 1file type in exclude list, skip file, i.e. do not
// *scan file
// *
// */
//
//int filetype_skipscan(pstring fname) {
//
//    /* as next_token modifies input */
//    pstring ex_list;
//    pstring exclude;
//    const char* p; /* needed to avoid compiler warning */
//    pstring ft_string, filetype_string;
//    char* p_ft;
//
//
//    if ( !filetype_init_magic ) {
//        if ( strlen(filetype_excludelist) == 0 ) {
//            DEBUG(5, ("exclude list is empty - feature disabled\n"));
//        } else {
//            DEBUG(5, ("libmagic init has failed  - feature disabled\n"));
//        }
//        return VSCAN_FT_ERROR_MUST_SCAN;
//    }
//
//    /* get the file type */
//    pstrcpy(ft_string, magic_file(filetype_magic, fname));
//    if ( ft_string == NULL ) {  /* error */
//        vscan_syslog("could not get file type, %s", magic_error(filetype_magic));
//        /* error occured */
//        return VSCAN_FT_ERROR_MUST_SCAN;
//    } /* end if */
//    trim_string(ft_string, " ", " ");
//    /* hack alert ... */
//    p_ft = ft_string;
//    pstrcpy(filetype_string, strsep(&p_ft, ";"));
//    DEBUG(5, ("file type of file %s is %s\n", fname, filetype_string));
//
//    /* next_token modifies input list, so copy it */
//    pstrcpy(ex_list, filetype_excludelist);
//
//    /* to avoid compiler warnings */
//    p = ex_list;
//
//    while ( next_token(&p, exclude, ";", sizeof(exclude)) ) {
//        trim_string(exclude, " ", " ");
//        DEBUG(5, ("current exclude type is: '%s'\n", exclude));
//        if ( StrCaseCmp(exclude, filetype_string) == 0 ) {
//            /* file type is in exlude list */
//            DEBUG(5, ("file type '%s' is in exclude list\n", exclude));
//            /* advise to skip scanning of file */
//            return VSCAN_FT_SKIP_SCAN;
//        } /* end if */
//    } /* end while */
//
//    /* file must be scanned */
//    DEBUG(5, ("no match - file must be scanned\n"));
//    return VSCAN_FT_MUST_SCAN;
//}

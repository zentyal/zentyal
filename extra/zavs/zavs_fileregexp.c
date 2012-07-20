#include <stdbool.h>
#include <string.h>
#include <pcre.h>

#include "zavs_fileregexp.h"
#include "zavs_log.h"

#define OVECCOUNT 30 // Should be a multiple of 3


static pcre *exclude_re = NULL;

bool fileregexp_init(const char *exclude_regexp)
{
    if (strnlen(exclude_regexp, sizeof(exclude_regexp)) > 0) {
        const char *error;
        int erroffset;

        ZAVS_DEBUG(5, "exclude regular expression is: '%s'\n", exclude_regexp);

        // Compile the regular expression
        exclude_re = pcre_compile(
                exclude_regexp, // the pattern, C string terminated by a binary zero
                0,              // default options
                &error,         // for error message
                &erroffset,     // for error offset
                NULL);          // use default character tables

        if (exclude_re == NULL) {
            ZAVS_ERROR("PCRE compilation of pattern '%s' failed at offset %d: %s\n", exclude_regexp, erroffset, error);
            return ZAVS_FR_ERROR_MUST_SCAN;
        }
    } else {
        ZAVS_DEBUG(5, "exclude regexp is empty - nothing to do\n");
    }

    return true;
}

void fileregexp_close(void)
{
    if (exclude_re != NULL) {
        pcre_free(exclude_re);
        exclude_re = NULL;
    }
}

/**
 *
 * Determins whether scan of file should be skipped or not
 *
 * @param fnamefile name
 * @return
 *      -1  error occured; file must be scanned
 *       0  file not in list, file must be scanned
 *       1  file in exclude regexp, skip file, i.e. do not
 *          scan file
 *
 */
int fileregexp_skipscan(const char *fname)
{
    if (exclude_re != NULL) {
        int ovector[OVECCOUNT];

        int rc;
        rc = pcre_exec(
                exclude_re,     // The compiled pattern
                NULL,           // no extra data - we didn't study the pattern
                fname,          // the subject string
                strlen(fname),  // the length of the subject
                0,              // start at offset 0 in the subject
                0,              // default options
                ovector,        // output vector for substring information
                OVECCOUNT);     // number of elements in the output vector

        // Matching failed, handle error cases
        if (rc < 0) {
            switch (rc) {
                case PCRE_ERROR_NOMATCH:
                    ZAVS_DEBUG(5, "File name '%s' no match regular expression\n", fname);
                    return ZAVS_FR_MUST_SCAN;
                    break;
                default:
                    ZAVS_DEBUG(5, "Unexpected error executing regular expression: %d\n", rc);
                    return ZAVS_FR_ERROR_MUST_SCAN;
                    break;
            }
        }

        // Match succeded
        ZAVS_DEBUG(5, "File name '%s' matched the regular expression, skip scan\n", fname);
        return ZAVS_FR_SKIP_SCAN;
    }

    return ZAVS_FR_MUST_SCAN;
}

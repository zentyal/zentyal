#ifndef __VFS_ZAVS_LOG_H__
#define __VFS_ZAVS_LOG_H__

#include <syslog.h>

#define ZAVS_DEBUG(_lvl, _fmt, ...) do { \
    syslog(LOG_DEBUG, "(%s:%d): " _fmt, __func__, __LINE__, ##__VA_ARGS__); \
} while (0)

#define ZAVS_INFO(_fmt, ...) do { \
    syslog(LOG_INFO, "INFO: " _fmt, ##__VA_ARGS__); \
} while (0)

#define ZAVS_WARN(_fmt, ...) do { \
    syslog(LOG_WARNING, "WARNING: " _fmt, ##__VA_ARGS__); \
} while (0)

#define ZAVS_ERROR(_fmt, ...) do { \
    syslog(LOG_ERROR, "ERROR: " _fmt, ##__VA_ARGS__); \
} while (0)

#endif

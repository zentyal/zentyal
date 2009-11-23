#ifndef __VSCAN_FUNCTIONS_H_
#define __VSCAN_FUNCTIONS_H_

#define MAX_ENC_LENGTH_STR 8196

BOOL set_boolean(BOOL *b, const char *value);
void vscan_syslog(const char *printMessage, ...);
void vscan_syslog_alert(const char *printMessage, ...);
char* encode_string (const char *s);

#endif /* __VSCAN_FUNCTIONS_H */

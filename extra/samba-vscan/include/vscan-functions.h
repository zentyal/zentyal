#ifndef __VSCAN_FUNCTIONS_H_
#define __VSCAN_FUNCTIONS_H_

#define MAX_ENC_LENGTH_STR 8196

void vscan_syslog(const char *printMessage, ...);
void vscan_syslog_alert(const char *printMessage, ...);
char* encode_string (const char *s);
int vscan_inet_socket_init(const char* daemon_name, const char* ip, const unsigned short int port);
int vscan_unix_socket_init(const char* daemon_name, const char* socket_name);
void vscan_socket_end (int sockfd);

#endif /* __VSCAN_FUNCTIONS_H */

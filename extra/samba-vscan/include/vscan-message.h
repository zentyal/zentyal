#ifndef __VSCAN_MESSAGE_H_
#define __VSCAN_MESSAGE_H_

int vscan_send_warning_message(const char *filename, const char *virname, const char *ipaddr);
void send_message(const char *msg);

#endif /* __VSCAN_MESSAGE_H_ */

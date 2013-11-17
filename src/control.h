#ifndef __CONTROL_H__
#define __CONTROL_H__

void control_abort(struct status *status);
bool control_init(struct status *status);
void control_free(struct status *status);
amqp_bytes_t control_handle(struct status *status, amqp_bytes_t request);

#endif

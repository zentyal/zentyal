#ifndef __RPC_H__
#define __RPC_H__

struct status;
bool rpc_open(struct status *status);
void rpc_close(struct status *status);
void rpc_run(struct status *status);

#endif

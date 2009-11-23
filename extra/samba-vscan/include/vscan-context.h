#ifndef __VSCAN_CONTEXT_H_
#define __VSCAN_CONTEXT_H_

/* increment this if you change anything in this file */
/* version 0: until I got the first working version --metze */
#define VSCAN_CONTEXT_VERSION 0

typedef struct vscan_config {
	struct vscan_context *context;
	const char *backend;
	const char *file;
	ssize_t max_size;
	bool verbose_file_logging;
	bool scan_on_open;
	bool scan_on_close;
	bool scan_on_sendfile;
	bool scan_on_rename;
	bool deny_access_on_error;
	bool deny_access_on_minor_error;
	bool send_warning_message;
	const char *scanner_addr;
	unsigned short int scanner_port;
	const char *quarantine_dir;
	const char *quarantine_prefix;
	enum infected_file_action_enum infected_file_action;
	int max_lrufiles;
	time_t lrufiles_invalidate_time;
} VSCAN_CONFIG;

typedef struct vscan_functions {
	int (*init1)(struct vscan_context *context);
	int (*config)(struct vscan_context *context);
	int (*init2)(struct vscan_context *context);
	int (*open)(struct vscan_context *context);
	int (*scan)(struct vscan_context *context, const char *fname,const char* newname, int flags, mode_t mode);
	int (*close)(struct vscan_context *context);
	int (*fini)(struct vscan_context *context);
} VSCAN_FUNCTIONS;

typedef struct vscan_backend {
	struct vscan_context *context;
	const struct vscan_functions *fns;
	TALLOC_CTX *mem_ctx;
	void *privates;
} VSCAN_BACKEND;

typedef struct vscan_context {
	TALLOC_CTX *mem_ctx;
	vfs_handle_struct *handle;
	struct vscan_config *config;
	struct vscan_backend *backend;
} VSCAN_CONTEXT;

NTSTATUS vscan_register_backend(int version, const char *name, const VSCAN_FUNCTIONS *fns);

#endif /* __VSCAN_CONTEXT_H */

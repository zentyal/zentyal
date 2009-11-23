/*
 * libmksd.c, ver. 1.05
 * copyright (c) MkS Sp. z o.o. 2002,2003
 * license: LGPL (see COPYING.LIB for details)
 */

#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/uio.h>
#include <sys/param.h>

#include "libmksd.h"

#define MAXTRIES 5


static char *cwd = NULL;
static int cwdlen;
static int fd = -1;


static inline int do_writev (struct iovec *iov, int iovcnt)
{
	int i;
	
	for (;;) {
		do
			i = writev (fd, iov, iovcnt);
		while ((i < 0) && (errno == EINTR));
		if (i <= 0)
			return -1;
		
		for (;;)
			if (i >= iov->iov_len) {
				if (--iovcnt == 0)
					return 0;
				i -= iov->iov_len;
				iov ++;
			} else {
				iov->iov_len -= i;
				iov->iov_base = (void *)((char *)iov->iov_base + i);
				break;
			}
	}
	return 0;
}

static inline int read_result_line (char *s)
{
	int i;
	
	do {
		do
			i = read (fd, s, 4096);
		while ((i < 0) && (errno == EINTR));
		if (i <= 0)
			return -1;
		s += i;
	} while (s[-1] != '\n');
	
	s[-1] = '\0';
	
	return 0;
}

static int get_cwd (void)
{
	if ((cwd = getcwd (NULL, 0)) == NULL)
		return -1;
	
	cwdlen = strlen (cwd);
	cwd [cwdlen++] = '/';
	
	return 0;
}


int mksd_connect (void)
{
	struct sockaddr_un serv;
	unsigned sun_len;
	int i, cnt = 0;
	struct timespec ts = {1, 0};
	
	if ((fd = socket (PF_UNIX, SOCK_STREAM, 0)) < 0)
		return -1;
	
	strcpy (serv.sun_path, "/var/run/mksd/socket");
	sun_len = SUN_LEN (&serv);
#ifdef _44BSD_
	serv.sun_len = sun_len;
#endif
	serv.sun_family = AF_UNIX;
	
	do {
		if (cnt > 0)
			nanosleep (&ts, NULL);
		i = connect (fd, (struct sockaddr *)&serv, sun_len);
	} while ((i < 0) && (errno == EAGAIN) && (++cnt < MAXTRIES));
	if (i < 0)
		return -1;
	
	return fd;
}

int mksd_query (const char *que, const char *prfx, char *ans)
{
	struct iovec iov [4];
	char enter = '\n';
	int len, plen, n = 0;
	
	for (len = 0; que [len] != '\0'; len++)
		if (que [len] == '\n')
			return -1;
	if (len > MAXPATHLEN)
		return -1;
	if ((plen = (prfx ? strlen (prfx) : 0)) > 16)
		return -1;
	
	if (plen) {
		iov[0].iov_base = (void *)prfx;
		iov[0].iov_len = plen;
		n = 1;
	}
	
	if (*que != '/') {
		if (cwd == NULL)
			if (get_cwd () != 0)
				return -1;
		iov[n].iov_base = (void *)cwd;
		iov[n].iov_len = cwdlen;
		n ++;
		
		if ((que[0] == '.') && (que[1] == '/')) {
			que += 2;
			len -= 2;
		}
	}
	
	iov[n].iov_base = (void *)que;
	iov[n].iov_len = len;
	n ++;
	
	iov[n].iov_base = (void *)&enter;
	iov[n].iov_len = 1;
	n ++;
		
	if (do_writev (iov, n) < 0)
		return -1;
	
	return read_result_line (ans);
}

void mksd_disconnect (void)
{
	close (fd);
	fd = -1;
	
	free (cwd);
	cwd = NULL;
}

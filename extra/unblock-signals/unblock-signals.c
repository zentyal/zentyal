/*
 * unblock-signals.c: Unblocks signals before performing an execvp or execve
 *
 * Copyright (C) 2008, Isaac Clerencia <isaac@warp.es>
 */
#define _GNU_SOURCE

#include <sys/file.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <assert.h>
#include <features.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include <signal.h>

#define _NAME(foo) #foo
#define NAME(foo) _NAME(foo)

int execv(const char *file, char *const argv[]) {
	static int (*libc_execv)(const char *file, char *const argv[]) = NULL;

	if(!libc_execv)
		libc_execv = (typeof(libc_execv))dlsym (RTLD_NEXT, NAME(execv));

    int res;
	
	sigset_t set;
	sigfillset(&set);
    sigprocmask(SIG_UNBLOCK, &set, NULL);
	
	res = (*libc_execv)(file,argv);
	return res;
}


int execve(const char *file, char *const argv[], char *const envp[]) {
	static int (*libc_execve)(const char *file, char *const argv[], char *const envp[]) = NULL;

	if(!libc_execve)
		libc_execve = (typeof(libc_execve))dlsym (RTLD_NEXT, NAME(execve));

    int res;
	
	sigset_t set;
	sigfillset(&set);
    sigprocmask(SIG_UNBLOCK, &set, NULL);
	
	res = (*libc_execve)(file,argv,envp);
	return res;
}

int execvp(const char *file, char *const argv[]) {
	static int (*libc_execvp)(const char *file, char *const argv[]) = NULL;

	if(!libc_execvp)
		libc_execvp = (typeof(libc_execvp))dlsym (RTLD_NEXT, NAME(execvp));

    int res;
	
	sigset_t set;
	sigfillset(&set);
    sigprocmask(SIG_UNBLOCK, &set, NULL);
	
	res = (*libc_execvp)(file,argv);
	return res;
}

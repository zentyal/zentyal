//--------------------------------useful definitions----------------------------
#define VERBOSE		0
#define	PATH		0
#define SILENT		0x01
#define	SHMEM		0x04

/******************************************************************************
*			KAV client C library				      *
*		(an implementation of KAVdaemon interface)		      *
******************************************************************************/
/*KAVConnect()- create a socket and connect it to KAVDaemon is running
  path_to daemon - path to AvpCtl file
  possible flags - does nothing anymore 
*/
int KAVConnect(char *path_to_daemon_ctl,char flags);

/*KAVRequestShmem() - send request string to KAVDaemon via created socket
   using shared memory
  - "kav_socket" - descriptor of an open socket, connected to kavdaemon
  - "path" may point to a single file;
  - "keyname" is a filename to use in shmem key construction
  - "chSHM" is a character	---	""	---
  - "flags" does nothing anymore
*/

int KAVRequestShmem(int kav_socket, char *path, char *keyname, char chSHM,char flags);

/*KAVRequestPath() - send simple one-target request, transmitting a path
  to the target.
  - "kav_socket" - descriptor of an open socket, connected to kavdaemon
  - "path" may point to a single file or to a directory
  - "flags" does nothing anymore
*/
int KAVRequestPath(int kav_socket, char *path, char flags);

/*KAVRequestMulti() - send multi-target request, transmitting a path
  to the target(s), a set of dirs, allowed to scan in and keys for KAVdaemon
  - "kav_socket" - descriptor of an open socket, connected to kavdaemon
  - "keys" is an array of keys to KAV Daemon for current request ending with 0;
  - "paths" is an array of paths, in which KAVDaemon can perform scanning/curing,
  	ending with 0 (NULL);
  - "flags" does nothing anymore
*/
int KAVRequestMulti(int kav_socket, char** keys,char** paths,char flags);

/*KAVResponse() - receive response from KAVDaemon on a previously sent request,
  fills account buffer if account info is provided and returns a pointer to it.
  by KAVDaemon. Returns 0 in case of an error
  - "kav_socket" - descriptor of an open socket, connected to kavdaemon
  - "exit code is a pointer to an int variable to store kavdaemon's exit code
  - "file" argument is used to write cured file to if SHMEM flag is set;
  - possible flags - {PATH/SHMEM}
	{PATH/SHMEM}	- file was transferred to daemon as its path
	{PATH,default} or in a shared memory{SHMEM}
*/
char* KAVResponse(int kav_socket,int* exit_code,char flags,char* file);

/*KAVVersion() - sends enquiry for version returns a ointer to a buffer
  with version info or 0 in case of an error
  - "kav_socket" - descriptor of an open socket, connected to kavdaemon
  - "flags" does nothing anymore
*/
char* KAVVersion(int kav_socket, char flags);

/*KAVClose() - close a session with KAV Daemon
  - "kav_socket" - descriptor of an open socket, connected to kavdaemon
  - possible flags does nothing anymore
*/
int KAVClose(int kav_socket,char flags);


//All functions except KAVResponse and KAVVersion return <0 in case of error.
//------------------------------------------------------------------------------

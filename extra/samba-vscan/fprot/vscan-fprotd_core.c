/* 
 * $Id: vscan-fprotd_core.c,v 1.27 2003/06/18 10:19:52 mx2002 Exp $
 *
 * Core Interface for F-Prot Antivirus Daemon			
 *
 * Copyright (C) Rainer Link, 2001-2003
 *               OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * Credits to W. Richard Stevens - RIP
 * 
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/

#include "vscan-global.h" 
#include "vscan-fprotd_core.h"

/* hum, global vars ... */
extern BOOL verbose_file_logging;
extern BOOL send_warning_message;
extern fstring fprotd_ip;
extern pstring fprotd_port;
extern fstring fprotd_args; 



/* initialise socket to F-Prot Daemon 
   returns -1 on error or the socket descriptor */
int vscan_fprotd_init(void)
{

	int sockfd;
	struct sockaddr_in servaddr;
	static pstring ports;
	fstring port;
	const char *p;

	/* create socket */
        if (( sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0 ) {
               vscan_syslog("ERROR: can not create socket!");
               return -1; 
        }

	bzero(&servaddr, sizeof(servaddr));
        servaddr.sin_family = AF_INET;

	/* hm, inet_pton may not exist on all systems - FIXME ! */
        if ( inet_pton(AF_INET, fprotd_ip, &servaddr.sin_addr) <= 0 ) {
                vscan_syslog("ERROR: inet_pton failed!");
                return -1;
	}

	/* next_token modifies input, so make a copy */
	pstrcpy(ports, fprotd_port);
	/* hum, needed to avoid compiler warning ... */
	p = ports;
	while ( next_token(&p, port, ";", sizeof(port)) ) {
		servaddr.sin_port = htons(atoi(port));
		/* connect to socket */
		if ( connect(sockfd, (struct sockaddr *) &servaddr, sizeof(servaddr)) < 0 )
        	{
                	vscan_syslog("ERROR: can not connect to F-Prot Daemon (IP: '%s', port: '%s')!", fprotd_ip, port);
			/* let's go sleeping for 1 second */
			/* sleeping causes too much slowdown */
			/* sleep(1); */
        	} else {
			/* OK, we got a connection. */
			return sockfd;
		}
	}

	/* Uh, no connection was possible */
	return -1;
}

/*
  If virus is found, logs the filename/virusname into syslog
*/
void vscan_fprotd_log_virus(char *infected_file, char *result, char* client_ip)
{
	char *str;
	size_t len;

	/* remove "<name>" and "</name>"from the result string to get only the virus name - hack alert ;) */

	/* some sanity checks ... */
	len = strlen(result);
	if ( len < 8 ) {
		/* hum, sth went wrong */
		vscan_syslog_alert("ALERT - Scan result: '%s' infected with virus 'UNKNOWN', client: '%s'", infected_file, client_ip);
		if ( send_warning_message )
			vscan_send_warning_message(infected_file, "UNKNOWN", client_ip);

	} else {
		str = result;
		str+= 6;
		str[strlen(str)-8] = '\0';

        	vscan_syslog_alert("ALERT - Scan result: '%s' infected with virus '%s', client: '%s'", infected_file, str, client_ip);
		if ( send_warning_message )
			vscan_send_warning_message(infected_file, str, client_ip);

	}
        
}



/*
  Scans a file (*FILE*, not a directory - keep that in mind) for a virus
  Expects socket descriptor and file name to scan for
  Returns -2 on minor error,  -1 on error, 0 if no virus was found, 
  1 if a virus was found 
*/
int vscan_fprotd_scanfile(int sockfd, char *scan_file, char* client_ip)
{
	char recvline[MAXLINE + 1];
	pstring fprotdCommand;	/* the command line to be send to daemon */
	char *str;
	FILE *fpin, *fpout;
	BOOL received_data = False; /* indicates, if any response from deamon was received */

	/* open stream sockets */
        fpin = fdopen(sockfd, "r");
        if ( fpin == NULL ) {
                vscan_syslog("ERROR: Can not open stream for reading - %s", strerror(errno));
                return -1;
        }

        fpout = fdopen(sockfd, "w");
        if ( fpout == NULL ) {
                vscan_syslog("ERROR: Can not open stream for writing - %s", strerror(errno));
                return -1;
        }


	if ( verbose_file_logging )
	        vscan_syslog("INFO: Scanning file : '%s'", scan_file);

	/* F-Prot Daemon expects "GET <filename>[?<arguments>] HTTP/1.0\r\n\r\n" */
	/* what about if the <filename> itself contains '\n'? */
        pstrcpy(fprotdCommand, "GET ");
        pstrcat(fprotdCommand, encode_string(scan_file));
	pstrcat(fprotdCommand, "?");
	pstrcat(fprotdCommand, fprotd_args);
        pstrcat(fprotdCommand, " HTTP/1.0\r\n\r\n");

	/* write to socket */
	/* NOTE: what happens if scan_file is very long? */

	if ( fputs(fprotdCommand, fpout) == EOF ) {
		vscan_syslog("ERROR: can not send file name to F-Prot Daemon!");
		return -1;
	}

	/* hum, instead of flush()ing, use setvbuf to set to line-buffering? */
        if ( fflush(fpout) == EOF ) {
                vscan_syslog("ERROR: can not flush output stream - %s", strerror(errno));
		/* better safe than sorry ... */
		return -1;
        }


	/* read from socket, line by line */
	setvbuf(fpin, (char *)NULL, _IOLBF, 0);
	/* setlinebuf(fpin); */

	while ( (fgets(recvline, MAXLINE, fpin)) != NULL ) {

		received_data = True;

		/* ignore the HTTP response header, remove any leading 
		   white spaces */
		str = NULL;
		str = strchr(recvline, '<');
		if ( str != NULL ) {
			if ( strncmp(str, "<name>", 6) == 0 ) {
				/* virus found */
				vscan_fprotd_log_virus(scan_file, str, client_ip);
				return 1;
			} else if ( strncmp(str, "<error>", 7) == 0 ) {
				/* ERROR */
				if ( verbose_file_logging )
					vscan_syslog("ERROR: file %s not found, not readable or an error occured", scan_file);
				return -2;
			}
		}
	}

	/* did we receive any data from daemon? */
	if ( !received_data ) {
		vscan_syslog("ERROR: can not get result from F-Prot Daemon!");
		return -1;
         } else {

	 	/* OK */
		if ( verbose_file_logging )
        		vscan_syslog("INFO: file %s is clean", scan_file);
	}

	return 0;
}


/*
  close socket
*/
void vscan_fprotd_end(int sockfd)
{
	/* sockfd == -1 indicates an error while connecting to socket */
	if ( sockfd >= 0 ) {
		close(sockfd);
	}

}

/* 
 * $Id: vscan-icap_core.c,v 1.7 2003/06/18 10:19:52 mx2002 Exp $
 *
 * Core Interface for ICAP			
 *
 * Copyright (C) Rainer Link, 2002-2003
 *               OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/

#include "vscan-global.h"
#include "vscan-icap_core.h"

#define BUFLEN 8196
#define MAXLINE 1024

extern BOOL verbose_file_logging;
extern BOOL send_warning_message;
extern fstring  icap_ip;
extern unsigned short int icap_port;

static const char ICAP_HEADER_S[] = "RESPMOD icap://localhost/avscan ICAP/1.0\r\nAllow: 204\r\nHost: localhost\r\nEncapsulated:";

static const char ENC_HEADER_S[] = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length:";



/* initialise socket to ICAP service 
   returns -1 on error or the socket descriptor */
int vscan_icap_init(void)
{

        int sockfd;
        struct sockaddr_in servaddr;

        /* create socket */
        if (( sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0 ) {
               vscan_syslog("ERROR: can not create socket!\n");
               return -1;
        }

        bzero(&servaddr, sizeof(servaddr));
        servaddr.sin_family = AF_INET;
        servaddr.sin_port = htons(icap_port);

        /* hm, inet_pton may not exist on all systems - FIXME ! */
        if ( inet_pton(AF_INET, icap_ip, &servaddr.sin_addr) <= 0 ) {
                vscan_syslog("ERROR: inet_pton failed!\n");
                return -1;
        }

        /* connect to socket */
        if ( connect(sockfd, (struct sockaddr *) &servaddr, sizeof(servaddr)) < 0 )
        {
                vscan_syslog("ERROR: can not connect to ICAP server (IP: '%s', port: '%d'!\n", icap_ip, icap_port);
                return -1;
        }


        return sockfd;

}

/*
  If virus is found, logs the filename/virusname into syslog
*/
void vscan_icap_log_virus(char *infected_file, char *result, char* client_ip)
{
	size_t len;
	char *str = NULL;

	str = strstr(result, "Threat=");
	if ( str != NULL ) {
		if ( strlen(str) > 7 ) {
			str += 7;
			len = strlen(strstr(str, ";\r\n"));
			str[strlen(str) - len] = '\0';
			vscan_syslog_alert("ALERT - Scan result: '%s' infected with virus '%s', client: '%s'", infected_file, str, client_ip);
	            if ( send_warning_message )
        	        vscan_send_warning_message(infected_file, str, client_ip);
		} else {
			vscan_syslog_alert("ALERT - Scan result: '%s' infected with virus 'UNKOWN', client: '%s'", infected_file, client_ip);
		        if ( send_warning_message )
                		vscan_send_warning_message(infected_file, "UNKNOWN", client_ip);
		}
	} else {
		vscan_syslog_alert("ALERT - Scan result: '%s' infected with virus 'UNKOWN', client: '%s'", infected_file, client_ip);
	        if ( send_warning_message )
                	vscan_send_warning_message(infected_file, "UNKNOWN", client_ip);
	}
}



/*
  Scans a file (*FILE*, not a directory - keep that in mind) for a virus
*/
int vscan_icap_scanfile(int sockfd, char *scan_file, char *client_ip)
{
        struct stat stat_buf;   
        size_t nread, nwritten;
        char ihs[BUFLEN];	/* ICAP Header string */
        char hrhs[BUFLEN];	/* HTTP Response Header string */
        char ehs[BUFLEN];	/* Encapsulated Header string */
        char ls[BUFLEN];	/* length string in hex */
        FILE *input_file = NULL;
        FILE *fpin, *fpout = NULL;
        char buf[BUFLEN];
        char recvline[MAXLINE + 1];
	char *str;
       	BOOL first_line = False; /* first line we've received? */
        BOOL infected = False;	/* an infected found? */


	/* get file length */
	bzero(&stat_buf, sizeof(stat_buf));
	/* FIXME: do we break LFS support here? */
        if ( stat(scan_file, &stat_buf) !=  0 ) {
		vscan_syslog("ERROR: could not stat file '%s'", scan_file);
		return(-1);
        }

	/* create Enculapsed header */
        snprintf(ehs, sizeof(ehs), "%s %u\r\n\r\n", ENC_HEADER_S, stat_buf.st_size);
	/* create length information line */
        snprintf(ls, sizeof(ls), "%x\r\n", stat_buf.st_size);
	/* create "faked" HTTP Request Header */
	snprintf(hrhs, sizeof(hrhs), "%s %s %s\r\n\r\n",
                        "GET",
                        scan_file,
                        "HTTP/1.1");
        /* create ICAP HEADER */
        snprintf(ihs, sizeof(ihs), "%s req-hdr=0, res-hdr=%u, res-body=%u\r\n\r\n",
                        ICAP_HEADER_S,
                        strlen(hrhs),
                        strlen(hrhs)+strlen(ehs));
        fpin = fdopen(sockfd, "r");
        if ( fpin == NULL ) {
                vscan_syslog("ERROR: can not open stream for reading - %s", strerror(errno));
                return -1;
        }

        fpout = fdopen(sockfd, "w");
        if ( fpout == NULL ) {
                vscan_syslog("ERROR: can not open stream for writing - %s", strerror(errno));
                return -1;
        } 

        if ( verbose_file_logging )
                vscan_syslog("INFO: Scanning file : '%s'", scan_file);

	/* send the headers */
	if ( fputs(ihs, fpout) == EOF ) {
		vscan_syslog("ERROR: could not send data to ICAP server!");
		return(-1);
	}
	if ( fputs(hrhs, fpout) == EOF ) {
		vscan_syslog("ERROR: could not send data to ICAP server!");
                return(-1);
        }
	if ( fputs(ehs, fpout) == EOF ) {
                vscan_syslog("ERROR: could not send data to ICAP server!");
                return(-1);
        }
	/* send length information in hex */
	if ( fputs(ls, fpout) == EOF ) {
                vscan_syslog("ERROR: could not send data to ICAP server!");
                return(-1);
	}
	fflush(fpout);

	/* now send the file ... */
        input_file = fopen(scan_file, "r");
        if ( input_file == NULL ) {
                vscan_syslog("ERROR: could not open file '%s', reason: %s", scan_file, strerror(errno));
                return(-1);
        }
        while ( (!feof(input_file)) && (!ferror(input_file)) ) {
                nread = fread(buf, 1, sizeof(buf), input_file);
                nwritten = fwrite(buf, 1, nread, fpout);
		if ( nread != nwritten ) {
			vscan_syslog("ERROR: error while sending data");
			return(-1);
		}
        }
	if ( ferror(input_file) ) {
		vscan_syslog("ERROR: error while reading file '%s'", scan_file);
		return(-1);
	}
	if ( fclose(input_file) == EOF ) {
		vscan_syslog("ERROR: could not close file '%s', reason: %s", scan_file, strerror(errno));
		return(-1);
	}

	/* now send the 'end marker' */
	if ( fputs("\r\n0\r\n\r\n", fpout) == EOF ) {
                vscan_syslog("ERROR: could not send data to ICAP server!");
                return(-1);
        }
        if ( fflush(fpout) == EOF ) {
                vscan_syslog("ERROR: can not flush output stream - %s", strerror(errno));
                return(-1); 
        }

	/* OK, now get the response from the ICAP server ... */

	/* set line buffering */
        setvbuf(fpin, (char *)NULL, _IOLBF, 0);

        first_line = True;
        while ( (fgets(recvline, MAXLINE, fpin)) != NULL ) {
		str = recvline;
		if ( first_line ) {
			if ( strncmp("ICAP", str,  4) == 0 ) {
				if ( strlen(str) > 11 ) {
					str+= 9;
                                        if ( strncmp("204", str, 3) == 0 ) {
						if ( verbose_file_logging )
							vscan_syslog("INFO: file %s is clean", scan_file);
						return(0);
                                        }
                                        else if ( strncmp("403", str, 3) == 0 ) {
                                                infected = True;
                                        } else {
						if ( verbose_file_logging )
							vscan_syslog("ERROR: file %s not found, not readable or an error occured", scan_file);
						return -2;
					}
                                } else {
					vscan_syslog("ERROR: could not parse ICAP response line!");
					return(-1);
                                }
                        } else {
				vscan_syslog("ERROR: got no ICAP response line!");
				return(-1);
                        }

                        first_line = False;
                }
		if ( infected ) {
			if ( strncmp("X-Infection-Found", str, 17) == 0 ) {
				vscan_icap_log_virus(scan_file, strstr(str, "Threat="), client_ip);
				return(1);
			}
		}
	}
	return(1);

}

/*
  close socket
*/
void vscan_icap_end(int sockfd)
{
        /* sockfd == -1 indicates an error while connecting to socket */
        if ( sockfd >= 0 ) {
                close(sockfd);
        }

}


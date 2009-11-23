/*
 * $Id: icap-client.c,v 1.4 2003/06/16 10:10:29 reniar Exp $
 *
 * example ICAP client for debugging/testing an ICAP server anti-virus
 * facility. Or, to simply scan a file for viruses :-)
 * Currently only Symantec AntiVirus Engine 4.x is supported. Other may
 * follow.
 *
 * Copyright (C) Rainer Link, 2002-2003
 *               OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * Compile it as "gcc -o icap-client icap-client.c"
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *  
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *  
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

/* maximum length of buffer */
#define BUFLEN 8196  

#define MAXLINE 1024
/* port ICAP server listens on as specified by ICAP protocol */
#define ICAP_PORT 1344
/* IP the ICAP server listens on */
#define ICAP_IP "127.0.0.1"
#define CLRF "\r\n"


#ifndef bool 
 #ifndef BOOL_DEFINED	/* BSD-systems */
   typedef int bool;
 #endif
#endif 

#ifndef FALSE
# define FALSE  0
#endif /* ! FALSE */
#ifndef TRUE
# define TRUE   1
#endif /* ! TRUE */


/* the ICAP RESPMOD header "template" */
static const char ICAP_HEADER_S[] = "RESPMOD icap://localhost/avscan ICAP/1.0\r\nAllow: 204\r\nHost: localhost\r\nEncapsulated:";

/* the ICAP encapsulated header "template" */ 
static const char ENC_HEADER_S[] = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length:";


void show_help(char* prgname)
{

	printf("\nUsage:\n");
	printf("%s file [-scr|-ssr|-sboth|-v|-h]\n\n", prgname);
	printf("Purpose:\n");
	printf("This program is a sample ICAP client implementation\nwhich sends the specified file to an ICAP server\nto be scanned for viruses\n\n");
	printf("Options:\n");
	printf("file	the file to be scanned by ICAP server\n");
	printf("-scr	show client request\n");
	printf("-ssr	show server response\n");
	printf("-sboth	show client request and server response\n");
	printf("-v	verbose mode\n");
	printf("-h	prints this help screen\n\n");
	printf("Return values:\n");
	printf("0 - All OK\n");
	printf("1 - virus found\n");
	printf("2 - error occured\n\n");
	printf("This software is licensed under the terms of the\nGNU General Public License (GPL)\n\n");
}		

int do_connection()
{
	int sockfd;
	struct sockaddr_in servaddr;

	/* create socket */
        if (( sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0 ) {
               printf("ERROR: can not create socket! Aborting.\n");
               exit(2);
        }

        bzero(&servaddr, sizeof(servaddr));
        servaddr.sin_family = AF_INET;
        servaddr.sin_port = htons(ICAP_PORT);
	
        /* hm, inet_pton may not exist on all systems - FIXME ! */
        if ( inet_pton(AF_INET, ICAP_IP, &servaddr.sin_addr) <= 0 ) {
                printf("ERROR: inet_pton failed! Aborting.\n");
                exit(2);
        }

	/* connect to socket */
        if ( connect(sockfd, (struct sockaddr *) &servaddr, sizeof(servaddr)) < 0 )
        {
                printf("ERROR: can not connect to ICAP server (IP: %s, port: %d)! Aborting.\n", ICAP_IP, ICAP_PORT);
               exit(2); 
        }

	return sockfd;
}

void close_connection(int sockfd)
{
        /* sockfd == -1 indicates an error while connecting to socket */
        if ( sockfd >= 0 ) {
                close(sockfd);
        }
}

void get_virus_name(char *infected_file, char *result)
{
        size_t len;
        char *str = NULL;

        str = strstr(result, "Threat=");
        if ( str != NULL ) {
                if ( strlen(str) > 7 ) {
                        str += 7;
                        len = strlen(strstr(str, ";\r\n"));
                        str[strlen(str) - len] = '\0';
                        printf("Scan result: File '%s' is infected with virus '%s'\n", infected_file, str);
                } else {
                         printf("Scan result: File '%s' is infected with virus 'UNKOWN'\n", infected_file);
                }
        } else {
                 printf("Scan result: File '%s' is infected with virus 'UNKOWN'\n", infected_file);
        }
}


int main(int argc, char* argv[]) 
{
	struct stat stat_buf;
	char* fname;
	bool verbose_mode = FALSE;
	bool show_request = FALSE;
	bool show_response = FALSE;
	int sockfd;
	off_t file_size;
        FILE *input_file = NULL;
        FILE *fpin, *fpout;
	char icap_header_str[BUFLEN];
	char http_response_header_str[BUFLEN];
	char encapsulated_header_str[BUFLEN];
	char file_length_hex[BUFLEN];
	char buf[BUFLEN];
        char recvline[MAXLINE + 1];
        char *str;
        bool first_line = FALSE; /* first line we've received? */
        bool infected = FALSE;  /* an infected found? */
	char host_name[256];	
	size_t len, nread, nwritten;

	
	printf("ICAP example client for use with Symantec AntiVirus Scan Engine 4.x\n");
	printf("(C) by Rainer Link, 2003, OpenAntiVirus.org, <rainer@openantivirus.org>\n\n");

	/* options parsing. No, I don't want to use getopt or popt ... */
	if ( argc < 2 ) {
		show_help(argv[0]);
		exit(1);
	} else if ( argc > 3 ) {
		printf("ERROR: too may options specified\n");
		show_help(argv[0]);
		exit(1);
	}	

	if ( strncmp("-h", argv[1], strlen(argv[1])) == 0 || 
	     strncmp("--help", argv[1], strlen(argv[1])) == 0 ) {
		show_help(argv[0]);
		exit(1);
	} else
		fname = argv[1];


	if ( argc == 3 ) {	
		if ( strncmp("-scr", argv[2], strlen(argv[2])) == 0 ) {
			show_request = TRUE;
		} else if ( strncmp("-ssr", argv[2], strlen(argv[2])) == 0 ) {
			show_response = TRUE;
		} else if ( strncmp("-sboth", argv[2], strlen(argv[2])) == 0 ) {
			show_request = TRUE;
			show_response = TRUE;
		} else if ( strncmp("-v", argv[2], strlen(argv[2])) == 0 ) {
			verbose_mode = TRUE;
		}			
	}

	/* check if file exists ... */
        if ( stat(fname, &stat_buf) !=  0 ) {
                printf("ERROR: file %s not found or stat() error. Aborting.\n", fname);
                exit(2);
        }
	/* check if it's regular file */
	if ( !(S_ISREG(stat_buf.st_mode)) ) {
		printf("ERROR: file %s is not a regular file. Aborting\n", fname);
		exit(2);
	}
	/* check if we can access the file */
	if ( access(fname, R_OK) < 0 ) {
		printf("ERROR: file %s not readable. Aborting.\n", fname);
		exit(2);
	}		
	
	file_size = stat_buf.st_size;

	/* establish connection to ICAP server */
	if ( verbose_mode ) printf("Open connection to ICAP server ...\n");
	sockfd = do_connection();

/*
        gethostname(host_name, sizeof(host_name)-1);
        printf("Host: %s\n", host_name);
*/

	if ( !show_request && !show_response) printf("Scanning file %s ...\n", fname);
	
	/* create the headers */
        /* create Enculapsed header */
        snprintf(encapsulated_header_str, sizeof(encapsulated_header_str), "%s %u\r\n\r\n", ENC_HEADER_S, file_size);
        /* create length information line */
        snprintf(file_length_hex, sizeof(file_length_hex), "%x\r\n", file_size);
        /* create "faked" HTTP Request Header */
        snprintf(http_response_header_str, sizeof(http_response_header_str), 
			"%s %s %s\r\n\r\n",
                        "GET",
                        fname,
                        "HTTP/1.1");
        /* create ICAP HEADER */
        snprintf(icap_header_str, sizeof(icap_header_str), "%s req-hdr=0, res-hdr=%u, res-body=%u\r\n\r\n",
                        ICAP_HEADER_S,
                        strlen(http_response_header_str),
                        strlen(http_response_header_str)+strlen(encapsulated_header_str));


	/* open stream for reading */
        fpin = fdopen(sockfd, "r");
        if ( fpin == NULL ) {
		printf("ERROR: an not open stream for reading - %s", strerror(errno));
		exit(2);
	}

	/* open stream for writing */
        fpout = fdopen(sockfd, "w");
        if ( fpout == NULL ) {
                printf("ERROR: can not open stream for writing - %s", strerror(errno)); 
		exit(2); 
	} 

	if ( verbose_mode ) printf("Sending headers to ICAP server ...\n");

        /* send the headers */
	if ( show_request) printf("%s", icap_header_str);
        if ( fputs(icap_header_str, fpout) == EOF ) {
                printf("ERROR: could not send data to ICAP server!");
                exit(2);
        }
	if ( show_request ) printf("%s", http_response_header_str);
        if ( fputs(http_response_header_str, fpout) == EOF ) {
                printf("ERROR: could not send data to ICAP server!");
                exit(2);
        }
	if ( show_request ) printf("%s", encapsulated_header_str);
        if ( fputs(encapsulated_header_str, fpout) == EOF ) {
                printf("ERROR: could not send data to ICAP server!");
                exit(2);
        }
        /* send length information in hex */
	if ( show_request ) printf("%s", file_length_hex);
        if ( fputs(file_length_hex, fpout) == EOF ) {
                printf("ERROR: could not send data to ICAP server!");
                exit(2);
        }
        fflush(fpout);

        /* now send the file ... */
	if ( verbose_mode ) printf("Sending file data to ICAP server ...\n");
        input_file = fopen(fname, "r");
        if ( input_file == NULL ) {
                printf("ERROR: could not open file '%s', reason: %s", fname, strerror(errno));
                exit(2);
        }
        while ( (!feof(input_file)) && (!ferror(input_file)) ) {
                nread = fread(buf, 1, sizeof(buf), input_file);
		if ( verbose_mode ) printf("read data: %u\n", nread);
		if ( show_request ) printf("%s", buf);
                nwritten = fwrite(buf, 1, nread, fpout);
		if ( verbose_mode ) printf("send data: %u\n", nwritten);
                if ( nread != nwritten ) {
                        printf("ERROR: error while sending data");
                        exit(2);
                }
        }

        if ( ferror(input_file) ) {
                printf("ERROR: error while reading file '%s'", fname);
                exit(2);
        }
        if ( fclose(input_file) == EOF ) {
                printf("ERROR: could not close file '%s', reason: %s", fname, strerror(errno));
                exit(2);
        }

        /* now send the 'end marker' */
        if ( fputs("\r\n0\r\n\r\n", fpout) == EOF ) {
                printf("ERROR: could not send data to ICAP server!");
                exit(2);
        }
	if ( show_request ) printf("\r\n0\r\n\r\n");

        if ( fflush(fpout) == EOF ) {
                printf("ERROR: can not flush output stream - %s", strerror(errno));
                exit(2); 
        }

        /* OK, now get the response from the ICAP server ... */
	if ( verbose_mode ) printf("Retrieving response from ICAP server ...\n");

        /* set line buffering */
        setvbuf(fpin, (char *)NULL, _IOLBF, 0);

        first_line = TRUE;
        while ( (fgets(recvline, MAXLINE, fpin)) != NULL ) {
		if ( show_response ) {
			printf("%s", recvline);
			continue;
		}
                str = recvline;
                if ( first_line ) {
                        if ( strncmp("ICAP", str,  4) == 0 ) {
				if ( verbose_mode ) printf("Found ICAP response line ...\n");
                                if ( strlen(str) > 11 ) {
                                        str+= 9;
                                        if ( strncmp("204", str, 3) == 0 ) {
						printf("Scan result: File %s is clean\n", fname);
						if ( verbose_mode ) printf("Closing connection to ICAP server ...\n");
						close_connection(sockfd);
						printf("\n");
                                                exit(0);
                                        }
                                        else if ( strncmp("403", str, 3) == 0 ) {
                                                infected = TRUE;
                                        } else {
                                                        printf("ERROR: %s", str);
                                                exit(2);
                                        }
                                } else {
                                        printf("ERROR: could not parse ICAP response line!");
                                        exit(2);
                                }
                        } else {
                                printf("ERROR: got no ICAP response line!");
                                exit(2);
                        }

                        first_line = FALSE;
                }

                if ( infected ) {
                        if ( strncmp("X-Infection-Found", str, 17) == 0 ) {
                                get_virus_name(fname, strstr(str, "Threat="));
				if ( verbose_mode ) printf("Closing connection to ICAP server ...\n");
				close_connection(sockfd);
				printf("\n");
                                return(1);
                        }
                }
        }

	if ( verbose_mode ) printf("Closing connection to ICAP server ...\n");
	close_connection(sockfd);

	exit(0);

}

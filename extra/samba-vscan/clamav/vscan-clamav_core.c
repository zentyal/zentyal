/*
 * $Id: vscan-clamav_core.c,v 1.5 2003/07/14 12:17:31 reniar Exp $
 * 
 * Core Interface for Clam AntiVirus Daemon
 *
 * Copyright (C) Rainer Link, 2001-2002
 *               OpenAntiVirus.org <rainer@openantivirus.org>
 *               Dariusz Markowicz <dariusz@markowicz.net>, 2003
 *
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/

#include "vscan-global.h" 
#include "vscan-clamav_core.h"

extern BOOL verbose_file_logging;
extern BOOL send_warning_message;
extern fstring clamd_socket_name;


/* initialise socket to clamd
   returns -1 on error or the socket descriptor  */
int vscan_clamav_init(void)
{

        int sockfd;
        struct sockaddr_un servaddr;

        /* create socket */
        if (( sockfd = socket(AF_UNIX, SOCK_STREAM, 0)) < 0 ) {
               vscan_syslog("ERROR: can not create socket!");
               return -1; 
        }

        bzero(&servaddr, sizeof(servaddr));
        servaddr.sun_family = AF_UNIX;
        safe_strcpy(servaddr.sun_path, clamd_socket_name, sizeof(servaddr.sun_path)-1);

        /* connect to socket */
        if ( connect(sockfd, (struct sockaddr *) &servaddr, sizeof(servaddr)) < 0 ) {
                vscan_syslog("ERROR: can not connect to clamd (socket: '%s')!", clamd_socket_name);
                return -1;
        }

    return sockfd;

}


/*
  If virus is found, logs the filename/virusname into syslog
*/
void vscan_clamav_log_virus(char *infected_file, char *results, char *client_ip)
{

    vscan_syslog_alert("ALERT - Scan result: '%s' infected with virus '%s', client: '%s'", infected_file, results, client_ip);
    if ( send_warning_message )
        vscan_send_warning_message(infected_file, results, client_ip);
        
}



/*
  Scans a file (*FILE*, not a directory - keep that in mind) for a virus
  Expects socket descriptor and file name to scan for
  Returns -2 on minor error,  -1 on error, 0 if a no virus was found, 
  1 if a virus was found
*/
int vscan_clamav_scanfile(int sockfd, char *scan_file, char *client_ip)
{
    char *request = NULL;
    size_t len = 0;
    int response = 0;
    char buff[1024];   
    char *vir = NULL, *p1 = NULL;
	FILE *fpin;

	/* open stream sockets */
    fpin = fdopen(sockfd, "r");
    if (fpin == NULL) {
        vscan_syslog("ERROR: Can not open stream for reading - %s", strerror(errno));
        return -1;
    }
 
    memset(buff, 0, sizeof(buff));

    /* +1 is for '\0' termination --metze */
    len = strlen("SCAN ")+strlen(scan_file)+1;
    /* prepare clamd command */
    if (!(request = (char *)malloc(len))) {
        vscan_syslog("ERROR: can not allocate memory");
        return -1; /* error allocating memory */
    }

    if (verbose_file_logging)
        vscan_syslog("INFO: Scanning file : '%s'", scan_file);

    safe_strcpy(request, "SCAN ", len-1);
    safe_strcat(request, scan_file, len-1); 
    if (write(sockfd, request, strlen(request)) != strlen(request)) {
        if (request) {
            free(request);
        }
        vscan_syslog("ERROR: can not write to the clamd socket");
        return -1; /* error writing to the clamd socket */
    }

    if (request) {
        free(request);
    }

    if (fgets((char *)&buff, sizeof(buff), fpin) > 0) {
        fclose(fpin);
        /* virus found */    
        if ((p1 = strstr(buff, "FOUND\n"))) {
            response = 1;
    
            vir = strchr(buff, ':') + 1;
            p1--;

            /* remove trailing and beginning spaces */
            while ((isspace((int)*p1)) && (p1 >= vir)) {
                *p1-- = '\0';
            }
            while (isspace((int)*vir)) {
                vir++;
            }
        
            vscan_clamav_log_virus(scan_file, vir, client_ip);
            return 1;
        } else if ((p1 = strstr(buff, "OK\n"))) {
            if (verbose_file_logging) {
                vscan_syslog("INFO: file %s is clean", scan_file);
            }
            return 0;
        } else {
            if (verbose_file_logging) {
                vscan_syslog("ERROR: file %s not found, not readable or an error occured", scan_file);
            }
            return -2;
        }
    }
    
    if (fpin) {
        fclose(fpin);
    }
    
    vscan_syslog("ERROR: can not get result from clamd");
    return -1;
}

/*
  close socket
*/
void vscan_clamav_end(int sockfd)
{

        /* sockfd == -1 indicates an error while connecting to socket */
        if ( sockfd >= 0 ) {
                close(sockfd);
        }

}
 

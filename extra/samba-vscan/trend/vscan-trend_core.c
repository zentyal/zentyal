/*
 * $Id: vscan-trend_core.c,v 1.18 2003/06/25 08:00:52 mx2002 Exp $
 * 
 * Core Interface for Trophie
 *
 * Copyright (C) Rainer Link, 2001-2002
 *               OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * This stuff is heavily based on Trophie by
 * Copyright (C) Vanja Hrustic, 2001
 *
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/

#include "vscan-global.h"
#include "vscan-trend_core.h"

extern BOOL verbose_file_logging;
extern BOOL send_warning_message;
extern fstring trophie_socket_name;


/* initialise socket to Trophie
   returns -1 on error or the socket descriptor  */
int vscan_trend_init(void)
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
        safe_strcpy(servaddr.sun_path, trophie_socket_name, sizeof(servaddr.sun_path)-1);

        /* connect to socket */
        if ( connect(sockfd, (struct sockaddr *) &servaddr, sizeof(servaddr)) < 0 ) {
                vscan_syslog("ERROR: can not connect to Trophie (socket: '%s')!", trophie_socket_name);
                return -1;
        }

    return sockfd;

}


/*
  If virus is found, logs the filename/virusname into syslog
*/
void vscan_trend_log_virus(char *infected_file, char *results, char *client_ip)
{

	vscan_syslog_alert("ALERT - Scan result: '%s' infected with virus '%s', client: '%s'", infected_file, results, client_ip);
	if ( send_warning_message )
		vscan_send_warning_message(infected_file, results, client_ip);

        
}



/*
  Scans a file (*FILE*, not a directory - keep that in mind) for a virus
  Expects socket descriptor and file name to scan for
  Returns -2 on minor error, -1 on error, 0 if a no virus was found, 
  1 if a virus was found
*/
int vscan_trend_scanfile(int sockfd, char *scan_file, char *client_ip)
{

/*        char path[MAXPATHLEN]; */
	/* be in sync with vscan-sophos_core.c */
	char path[256];
        char buf[512];
        size_t len;
        int bread;

        /* take adding '\n' later into account */
        len = strlen(scan_file) + 2;
        if ( len > sizeof(path) ) {
                vscan_syslog("ERROR: Filename too large!");
                return -1;
        }

        memset(path, 0, sizeof(path));
        strncpy(path, scan_file, sizeof(path)-2);

/*  Trophie needs '\n'. How to deal with a file name, which contains '\n'
    somehwere in the file name? */

        path[strlen(path)] = '\n';


	if ( verbose_file_logging )
	        vscan_syslog("INFO: Scanning file : '%s'", scan_file);

        if (write(sockfd, path, strlen(path)) < 0) {
                vscan_syslog("ERROR: writing to Trophie socket failed!");
                return -1;
        } else {
                memset(buf, 0, sizeof(buf));
                if ( (bread = read(sockfd, buf, sizeof(buf))) > 0)
                {
                        if (strchr(buf, '\n'))
                                *strchr(buf, '\n') = '\0';

                        if (buf[0] == '1') {
                                /* Hehe ... */
                                char *virusname = buf+2;
                                vscan_trend_log_virus(scan_file, virusname, client_ip);

                                return 1;
                        } else if ( buf[0] == '-' && buf[1] == '1' ) {
				if ( verbose_file_logging ) 
					vscan_syslog("INFO: file %s not found, not readable or an error occured", scan_file);
				return -2;
                        } else {
                                if ( verbose_file_logging )
                                	vscan_syslog("INFO: file %s is clean", scan_file);
                                return 0;
                        }

                } else {
                        vscan_syslog("ERROR: can not get result from Trophie");
                        return -1;
                }
        }

	return -1;

}

/*
  close socket
*/
void vscan_trend_end(int sockfd)
{

        /* sockfd == -1 indicates an error while connecting to socket */
        if ( sockfd >= 0 ) {
                close(sockfd);
        }

}


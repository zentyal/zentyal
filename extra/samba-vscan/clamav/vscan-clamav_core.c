/*
 * $Id: vscan-clamav_core.c,v 1.5.2.12 2005/03/29 19:16:46 reniar Exp $
 * 
 * Core Interface for Clam AntiVirus Daemon
 *
 * Copyright (C) Rainer Link, 2001-2004
 *               OpenAntiVirus.org <rainer@openantivirus.org>
 *               Dariusz Markowicz <dariusz@markowicz.net>, 2003
 *
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/

#include "vscan-global.h" 
#include "vscan-clamav_core.h"

#ifdef LIBCLAMAV
#include <clamav.h>
#endif

extern BOOL verbose_file_logging;
extern BOOL send_warning_message;

#ifdef LIBCLAMAV
extern struct cl_node *clamav_root;
extern struct cl_limits clamav_limits;
extern BOOL clamav_loaded;
#else
extern BOOL scanarchives;
extern fstring clamd_socket_name;
#endif


#ifdef LIBCLAMAV
void vscan_clamav_lib_init()
{
    int ret;
    int no = 0;

    if ( (ret = cl_loaddbdir(cl_retdbdir(), &clamav_root, &no)) ) {
	vscan_syslog("ERROR: could not load clamav database, reason '%s'", cl_perror(ret));
	clamav_loaded = False;
    } else {

	clamav_loaded = True;
        DEBUG(3, ("Loaded %d virus signatures\n", no));

	/* build the trie */
        cl_buildtrie(clamav_root);

    }
}

#else	/* LIBCLAMAV */

/* initialise socket to clamd
   returns -1 on error or the socket descriptor  */
int vscan_clamav_init(void)
{

        return vscan_unix_socket_init("clamd", clamd_socket_name);
}


/*
  If virus is found, logs the filename/virusname into syslog
*/
void vscan_clamav_log_virus(const char *infected_file, const char *results, const char *client_ip)
{

    vscan_syslog_alert("ALERT - Scan result: '%s' infected with virus '%s', client: '%s'", infected_file, results, client_ip);
    if ( send_warning_message )
        vscan_send_warning_message(infected_file, results, client_ip);
        
}
#endif /* LIBCLAMAV */

#ifdef LIBCLAMAV
/* Scan a file using lib clamav
 Returns -2 on minor error,  -1 on error, 0 if a no virus was found,
 1 if a virus was found
*/
int vscan_clamav_lib_scanfile(char* scan_file, char* client_ip)
{
    int ret;
    unsigned long int size = 0;
    /* interface change sometime after 0.65 release */
    const char* virname;

    ret = cl_scanfile(scan_file, &virname, &size, clamav_root, &clamav_limits, CL_ARCHIVE);
    if ( ret == CL_CLEAN ) {    /* no virus found */
	if (verbose_file_logging) {
		vscan_syslog("INFO: file %s is clean", scan_file);
	}
	return VSCAN_SCAN_OK;
    }
    if ( ret == CL_VIRUS ) {  /* virus found */
	vscan_clamav_log_virus(scan_file, virname, client_ip);	
	return VSCAN_SCAN_VIRUS_FOUND;
    }
    /* error */
    vscan_syslog("ERROR: file %s not found, not readable or an error occured (lib return code: %d)", scan_file, ret);
    return VSCAN_SCAN_MINOR_ERROR;
}
#else	/* LIBCLAMAV */

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
    char buff[1024];   
    char *scanart = NULL;
    FILE *fpin;

    /* open stream sockets */
    fpin = fdopen(sockfd, "r");
    if (fpin == NULL) {
        vscan_syslog("ERROR: Can not open stream for reading - %s", strerror(errno));
        return VSCAN_SCAN_ERROR;
    }
 
    memset(buff, 0, sizeof(buff));

    /* +1 is for '\0' termination --metze */
    if ( scanarchives ) {
    	scanart = "SCAN ";
    } else {
    	scanart = "RAWSCAN ";
    }
    len = strlen(scanart)+strlen(scan_file)+1;

    /* prepare clamd command */
    if (!(request = (char *)malloc(len))) {
        vscan_syslog("ERROR: can not allocate memory");
        return VSCAN_SCAN_ERROR; /* error allocating memory */
    }

    if (verbose_file_logging)
        vscan_syslog("INFO: Scanning file : '%s'", scan_file);

    safe_strcpy(request, scanart, len-1);
    safe_strcat(request, scan_file, len-1); 
    if (write(sockfd, request, strlen(request)) != strlen(request)) {
        free(request);

        vscan_syslog("ERROR: can not write to the clamd socket");
        return VSCAN_SCAN_ERROR; /* error writing to the clamd socket */
    }

    free(request);

    if (fgets((char *)&buff, sizeof(buff), fpin) > 0) {
        char *p1;
        fclose(fpin);
        /* virus found */    
        if ((p1 = strstr(buff, "FOUND\n"))) {
            char *vir;
    
            vir = strchr(buff, ':') + 1;

            /* remove trailing and beginning spaces */
            while (isspace((int)*vir))
                vir++;
            for (--p1; (p1 >= vir) && (isspace((int)*p1)); p1--);
            p1[1] = '\0';

            vscan_clamav_log_virus(scan_file, vir, client_ip);
            return VSCAN_SCAN_VIRUS_FOUND;
        }
	if ((NULL !=  strstr(buff, "OK\n"))) {
            if (verbose_file_logging)
                vscan_syslog("INFO: file %s is clean", scan_file);

            return VSCAN_SCAN_OK;
        }

        vscan_syslog("ERROR: file %s not found, not readable or an error occured", scan_file);
        return VSCAN_SCAN_MINOR_ERROR;
    }

    fclose(fpin);

    vscan_syslog("ERROR: could not get result from clamd");
    return VSCAN_SCAN_ERROR;
}
#endif /* LIBCLAMAV */


#ifdef LIBCLAMAV
void vscan_clamav_lib_done()
{
    cl_freetrie(clamav_root);
}
#else /* LIBCLAMAV */

/*
  close socket
*/
void vscan_clamav_end(int sockfd)
{

	vscan_socket_end(sockfd);

}
 
#endif /* LIBCLAMAV */

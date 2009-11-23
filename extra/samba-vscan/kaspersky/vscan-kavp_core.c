/*
 * Core Interface for Kaspersky AntiVirus
 *
 * Copyright (C) Ries van Twisk, vscan@rvt.dds.nl, 2002
 * Copyright (C) Rainer Link, rainer@openantivirus.org, 2002-2003
 * Various fixes by Kevin Wang <kjw@rightsock.com>, 2003
 *
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/

#include "vscan-global.h"
#include "vscan-kavp.h"
#include "vscan-kavp_core.h"

extern BOOL verbose_file_logging;
extern BOOL send_warning_message;
extern fstring avpctl;


/*
  If virus is found, logs the filename/virusname into syslog
*/
void vscan_kavp_log_virus(char *infected_file, char *client_ip)
{
	// there seems no way to get the virus name :(        
	static char virusName[] = "UNKNOWN";

	vscan_syslog_alert("ALERT - Scan result: '%s' infected with virus '%s', client: '%s'", infected_file, virusName, client_ip);
	if ( send_warning_message )
		vscan_send_warning_message(infected_file, virusName, client_ip);

	return;
}

/* returns -1 if some error occurred
 * returns 1 if     infected; deny access to file
 * returns 0 if not infected; allow access to file
*/
int vscan_kavp_scanfile(char *scan_file, char* client_ip)
{
	int result;
	char* response;
	int exit_code;

	/* Check the socket */
	if (kavp_socket < 0) {
	    vscan_syslog("ERROR: connection to kavpdaemon was not open!\n");
    	    return -1;
	}

	/* Send scan request to kavdaeon */
	if ( verbose_file_logging )
		vscan_syslog("INFO: KAVRequestPath() scanning file [%s]\n", scan_file);

	if ( (result=KAVRequestPath(kavp_socket, scan_file, SILENT )) < 0) {
	    vscan_syslog("ERROR: KAVRequestMulti() failed (return code: [%d])\n", result);
	    return -1;
	}

	/* Receive status back about this file */	
	if ( (response=KAVResponse(kavp_socket, &exit_code, SILENT, 0)) ==0 ) {
	    vscan_syslog("ERROR: KAVResponse() failed (return code: [0])\n");
	    return -1;
	}

	if ((exit_code & 0xff) - 0x30) {
	    vscan_kavp_log_virus(scan_file, client_ip);
	    return 1;	// Found a virus; deny
	} 
	/* else no virus found */
	if ( verbose_file_logging )
	    vscan_syslog("INFO: file %s is clean", scan_file);

    return 0;	// Everything seems to be ok
}

/* Initialize VSAPI */
void vscan_kavp_init(void)
{
    kavp_socket = KAVConnect(avpctl, SILENT);
    if ( kavp_socket < 0 ) {
	vscan_syslog("ERROR: KAVConnect() to socket %s failed (return code: [%d])\n", avpctl, kavp_socket);
    }
    if ( verbose_file_logging )
        vscan_syslog("INFO: KAVConnect() returned fd %d \n", kavp_socket);
}

/* Bye, bye */
void vscan_kavp_end(void)
{
    int result;
    if ( kavp_socket>=0 ) {
	if ( (result=KAVClose(kavp_socket, SILENT)) == 0 ) {
	    if ( verbose_file_logging )
    	       vscan_syslog("INFO: Disconnected from kavdaemon; fd %d.\n", kavp_socket);	
            
	} else {
    	    vscan_syslog("ERROR: KAVClose() on fd %d failed (return code: [%d])\n", kavp_socket, result);	
        }
        close(kavp_socket);
	kavp_socket = -1;
    } else {
	vscan_syslog("INFO: Not closing a closed connection\n");
    }
}



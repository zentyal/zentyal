/* 
 * $Id: vscan-symantec_core.c,v 1.12 2003/06/18 10:19:53 mx2002 Exp $
 *
 * Core Interface for Symantec Carrier Scan			
 *
 * Copyright (C) Rainer Link, 2001-2002
 *               OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/

#include "vscan-global.h"
#include "vscan-symantec_core.h"

bool cscan_ok = TRUE;

HSCANCLIENT scanclient=NULL;


extern BOOL verbose_file_logging;
extern BOOL send_warning_message;
extern fstring cs_ip_port;



/* initialise CarrierScan */
void vscan_symantec_init(void)
{
	char pszStartUpString[MAX_STRING];

	snprintf(pszStartUpString, sizeof(pszStartUpString), "server:%s", cs_ip_port);

        if ( ScanClientStartUp( &scanclient, pszStartUpString) > 0 ) 
        {
                vscan_syslog("ERROR in ScanClientStartUp (IP:port: '%s')\n", cs_ip_port);
        	cscan_ok = FALSE;        
        }

}

/*
  If virus is found, logs the filename/virusname into syslog
*/
void vscan_symantec_log_virus(char *infected_file, HSCANRESULTS hResults, char *client_ip)
{
	char virusName[MAX_STRING];
	int attrib_size;

	attrib_size = MAX_STRING;
	ScanResultGetProblem( hResults, 0, SC_PROBLEM_VIRUSNAME, virusName, &attrib_size ); 

	
        vscan_syslog_alert("ALERT - Scan result: '%s' infected with virus '%s', client: '%s'", infected_file, virusName, client_ip);
	if ( send_warning_message )
		vscan_send_warning_message(infected_file, virusName, client_ip);

}



/*
  Scans a file (*FILE*, not a directory - keep that in mind) for a virus
*/
int vscan_symantec_scanfile(char *scan_file, char *client_ip)
{
	HSCANRESULTS results=NULL; 
        SCSCANFILE_RESULT answer;


	if ( verbose_file_logging )
	        vscan_syslog("Scanning file : '%s'", scan_file);

	answer = ScanClientScanFile(scanclient, scan_file, scan_file, NULL, "", &results); 
        if( answer > 0 )
        { 
                vscan_syslog("**** ERROR! Couldn't scan file %s\n", scan_file); 
                return -1;
        }


        switch (answer)
        {
		case SCSCANFILE_INF_NO_REP:
		case SCSCANFILE_INF_PARTIAL_REP:
		case SCSCANFILE_INF_REPAIRED:
			vscan_symantec_log_virus(scan_file, results, client_ip);
			ScanResultsFree(results); 
			return 1;
			break;

		case SCSCANFILE_CLEAN:
			if ( verbose_file_logging )
				vscan_syslog("INFO: file %s is clean", scan_file);
			ScanResultsFree(results);
              	  	return 0;
			break;
		default:
			vscan_syslog("ERROR: ScanClientScanFile returned an unexpected value\n");
			ScanResultsFree(results);
			/* FIXME: should we really return "minor error" here?!? */
			return -2;
       }
	
}

/*
  Cleanup
*/
void vscan_symantec_end(void)
{

	ScanClientShutDown(scanclient); 

        vscan_syslog("C API for CarrierScan cleaned up and released/terminated");

}

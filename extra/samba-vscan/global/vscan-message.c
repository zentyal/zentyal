/*
 * $Id: vscan-message.c,v 1.10.2.3 2007/09/15 14:35:43 reniar Exp $
 * 
 * NetBIOS message interface
 *
 * Copyright (C) William Harris <harris@perspectix.com>, 2002
 *               Rainer Link, 2002
 *		 OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/


#include "vscan-global.h"

static pstring username;
static struct cli_state *cli;
static int name_type = 0x03; /* messages are sent to NetBIOS name type 0x3 */
#if SAMBA_VERSION_MAJOR==2
static int port = SMB_PORT;
extern fstring remote_machine;
#elif SAMBA_VERSION_MAJOR==3
static int port = SMB_PORT2;
fstring remote_machine;
#endif

/****************************************************************************
 Handle a message operation.
***************************************************************************/

int vscan_send_warning_message(const char *filename, const char *virname, const char *ipaddr) {
    struct in_addr ip;
    struct sockaddr_storage ss;

        struct nmb_name called, calling;
	pstring myname;
	pstring message;
	pstring shortfilename;
	char* lastslash;

	static pstring lastfile;
	static pstring lastip;

	#if SAMBA_VERSION_MAJOR==3
	fstrcpy(remote_machine, get_remote_machine_name());
	DEBUG(5, ("remote machine is: %s\n", remote_machine));
	#endif

	/* Only notify once for a given virus/ip combo - otherwise the
	 * scanner will go crazy reaccessing the file and sending
	 * messages once the user hits the "okay" button */
	if (strncmp(lastfile,filename,sizeof(pstring)) == 0) {
		if (strncmp(lastip,ipaddr,sizeof(pstring)) == 0) {
			DEBUG(5,("Both IP and Filename are the same, not notifying\n"));
			return 0;
		}
	}

	ZERO_ARRAY(lastfile);
	ZERO_ARRAY(lastip);
	pstrcpy(lastfile,filename);
	pstrcpy(lastip,ipaddr);

	ZERO_ARRAY(myname);
	pstrcpy(myname,myhostname());

	ZERO_ARRAY(username);
	/* could make this configurable */
	snprintf(username,sizeof(pstring)-1,"%s VIRUS SCANNER",myname);

	/* We need to get the real ip structure from the ip string
	 * is this info already available somewhere else in samba? */
       	zero_ip(&ip);
	if (inet_aton(ipaddr,&ip) == 0) {
               	DEBUG(5,("Cannot resolve ip address %s\n", ipaddr));
               	return 1;
	}
    in_addr_to_sockaddr_storage(&ss, ip);


       	make_nmb_name(&calling, myname, 0x0);
       	make_nmb_name(&called , remote_machine, name_type);

	 if (!(cli=cli_initialise())) {
               	DEBUG(5,("Connection to %s failed\n", remote_machine));
               	return 1;
       	}
        cli_set_port(cli, port);
     if (!NT_STATUS_IS_OK(cli_connect(cli, remote_machine, &ss))) {
               	DEBUG(5,("Connection to %s failed\n", remote_machine));
               	return 1;
    }

       	if (!cli_session_request(cli, &calling, &called)) {
               	DEBUG(5,("session request failed\n"));
               	cli_shutdown(cli);
               	return 1;
       	}

	ZERO_ARRAY(shortfilename);
	/* we don't want the entire filename, otherwise the message service may choke
	 * so we chop off the path up to the very last forward-slash
	 * assumption: unix-style pathnames in filename (don't know if there's a
	 * portable file-separator variable... */
	lastslash = strrchr(filename,'/');
	if (lastslash != NULL && lastslash != filename) {
		pstrcpy(shortfilename,lastslash+1);
	} else {
		pstrcpy(shortfilename,filename);
	}

	ZERO_ARRAY(message);
	/* could make the message configurable and language specific? */
	snprintf(message,sizeof(pstring)-1,
		"%s IS INFECTED WITH VIRUS  %s.\r\n\r\nAccess will be denied.\r\nPlease contact your system administrator",
		shortfilename, virname);

	/* actually send the message... */
       	send_message(message);

       	cli_shutdown(cli);
	
        return 0;
}

void send_message(const char *msg) {
	pstring msg_conv;
	int len;
	int grp_id;

	#if SAMBA_VERSION_MAJOR==2
	 #if SAMBA_VERSION_RELEASE < 4
	    /* Samba 2.2.0-2.2.3 */
	    pstrcpy(msg_conv, unix_to_dos(msg, FALSE));
	 #else
	    /* Samba >= 2.2.4 */
	    pstrcpy(msg_conv, unix_to_dos(msg));
         #endif
	#elif SAMBA_VERSION_MAJOR==3
	push_ascii_pstring(msg_conv, msg);
	#endif

	len = strlen(msg_conv);

        if (!cli_message_start(cli, remote_machine, username, &grp_id)) {
                DEBUG(5,("message start: %s\n", cli_errstr(cli)));
                return;
        }

	if (!cli_message_text(cli, msg_conv, len, grp_id)) {
		DEBUG(5,("SMBsendtxt failed: %s\n",cli_errstr(cli)));
		return;
	}

        if (!cli_message_end(cli, grp_id)) {
                DEBUG(5,("SMBsendend failed: %s\n",cli_errstr(cli)));
                return;
        }   
}

/*
 * $Id: vscan-oav.c,v 1.46 2003/07/15 11:37:35 mx2002 Exp $
 * 
 * Core Interface for OpenAntiVirus ScannerDaemon			
 *
 * Copyright (C) Rainer Link, 2001-2002
 *               OpenAntiVirus.org <rainer@openantivirus.org>
 *
 * Copyright (C) Stefan Metzmacher, 2003
 *               <metze@metzemix.de>
 *
 * Credits to W. Richard Stevens - RIP
 * 
 * This software is licensed under the GNU General Public License (GPL)
 * See: http://www.gnu.org/copyleft/gpl.html
 *
*/

#include "vscan-global.h"
#include "vscan-oav.h"

static int vscan_oav_init1(VSCAN_CONTEXT *context)
{
	return 0;
}

static int vscan_oav_config(VSCAN_CONTEXT *context)
{
	return 0;
}

static int vscan_oav_init2(VSCAN_CONTEXT *context)
{
	return 0;
}

static int vscan_oav_open(VSCAN_CONTEXT *context)
{
	return 0;
}

static int vscan_oav_scan(VSCAN_CONTEXT *context, const char *fname, const char *newname, int flags, mode_t mode)
{
	errno = EACCES;
	return -1;
}

static int vscan_oav_close(VSCAN_CONTEXT *context)
{
	return 0;
}

static int vscan_oav_fini(VSCAN_CONTEXT *context)
{
	return 0;
}

static const VSCAN_FUNCTIONS vscan_oav_fns = {
	vscan_oav_init1,
	vscan_oav_config,
	vscan_oav_init2,
	vscan_oav_open,
	vscan_oav_scan,
	vscan_oav_close,
	vscan_oav_fini
};

NTSTATUS vscan_init_oav(void)
{
	return vscan_register_backend(VSCAN_CONTEXT_VERSION, "oav", &vscan_oav_fns);
}

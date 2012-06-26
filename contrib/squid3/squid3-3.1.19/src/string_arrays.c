
/*
 * $Id$
 *
 *
 * SQUID Web Proxy Cache          http://www.squid-cache.org/
 * ----------------------------------------------------------
 *
 *  Squid is the result of efforts by numerous individuals from
 *  the Internet community; see the CONTRIBUTORS file for full
 *  details.   Many organizations have provided support for Squid's
 *  development; see the SPONSORS file for full details.  Squid is
 *  Copyrighted (C) 2001 by the Regents of the University of
 *  California; see the COPYRIGHT file for full details.  Squid
 *  incorporates software developed and/or copyrighted by other
 *  sources; see the CREDITS file for full details.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111, USA.
 *
 */

const char *err_type_str[] = {
	"ERR_NONE",
	"ERR_READ_TIMEOUT",
	"ERR_LIFETIME_EXP",
	"ERR_READ_ERROR",
	"ERR_WRITE_ERROR",
	"ERR_SHUTTING_DOWN",
	"ERR_CONNECT_FAIL",
	"ERR_SECURE_CONNECT_FAIL",
	"ERR_INVALID_REQ",
	"ERR_UNSUP_REQ",
	"ERR_INVALID_URL",
	"ERR_SOCKET_FAILURE",
	"ERR_DNS_FAIL",
	"ERR_CANNOT_FORWARD",
	"ERR_FORWARDING_DENIED",
	"ERR_NO_RELAY",
	"ERR_ZERO_SIZE_OBJECT",
	"ERR_PRECONDITION_FAILED",
	"ERR_FTP_DISABLED",
	"ERR_FTP_FAILURE",
	"ERR_URN_RESOLVE",
	"ERR_ACCESS_DENIED",
	"ERR_CACHE_ACCESS_DENIED",
	"ERR_CACHE_MGR_ACCESS_DENIED",
	"ERR_SQUID_SIGNATURE",
	"ERR_FTP_PUT_CREATED",
	"ERR_FTP_PUT_MODIFIED",
	"ERR_FTP_PUT_ERROR",
	"ERR_FTP_NOT_FOUND",
	"ERR_FTP_FORBIDDEN",
	"ERR_FTP_UNAVAILABLE",
	"ERR_ONLY_IF_CACHED_MISS",
	"ERR_TOO_BIG",
	"TCP_RESET",
	"ERR_ESI",
	"ERR_INVALID_RESP",
	"ERR_ICAP_FAILURE",
	"ERR_UNSUP_HTTPVERSION",
	"ERR_GATEWAY_FAILURE",
	"ERR_MAX"
};

const char *lookup_t_str[] = {
	"LOOKUP_NONE",
	"LOOKUP_HIT",
	"LOOKUP_MISS"
};

const char *icp_opcode_str[] = {
	"ICP_INVALID",
	"ICP_QUERY",
	"ICP_HIT",
	"ICP_MISS",
	"ICP_ERR",
	"ICP_SEND",
	"ICP_SENDA",
	"ICP_DATABEG",
	"ICP_DATA",
	"ICP_DATAEND",
	"ICP_SECHO",
	"ICP_DECHO",
	"ICP_NOTIFY",
	"ICP_INVALIDATE",
	"ICP_DELETE",
	"ICP_UNUSED15",
	"ICP_UNUSED16",
	"ICP_UNUSED17",
	"ICP_UNUSED18",
	"ICP_UNUSED19",
	"ICP_UNUSED20",
	"ICP_MISS_NOFETCH",
	"ICP_DENIED",
	"ICP_HIT_OBJ",
	"ICP_END"
};

const char *swap_log_op_str[] = {
	"SWAP_LOG_NOP",
	"SWAP_LOG_ADD",
	"SWAP_LOG_DEL",
	"SWAP_LOG_VERSION",
	"SWAP_LOG_MAX"
};

/*
   Copyright (C) 2011-2013 Zentyal S.L.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License, version 2, as
   published by the Free Software Foundation.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include "console.h"
#include <arpa/inet.h>
#include <time.h>

using namespace std;

void ConsoleBWStatsDumper::dumpHost(HostStats *host) {
    char ip[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &(host->getIP()), ip, INET_ADDRSTRLEN);

    time_t rawtime;
    time(&rawtime);

    BWSummary* internal = host->getInternalBW();
    BWSummary* external = host->getExternalBW();

    cout << "IP=" << ip;
    cout << " TIMESTAMP=" << rawtime;
    cout << " INT_SENT=" << internal->totalSent;
    cout << " INT_RECV=" << internal->totalRecv;
    cout << " INT_TCP="  << internal->TCP;
    cout << " INT_UDP="  << internal->UDP;
    cout << " INT_ICMP=" << internal->ICMP;

    cout << " EXT_SENT=" << external->totalSent;
    cout << " EXT_RECV=" << external->totalRecv;
    cout << " EXT_TCP="  << external->TCP;
    cout << " EXT_UDP="  << external->UDP;
    cout << " EXT_ICMP=" << external->ICMP;
    cout << endl;
}


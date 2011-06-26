/*
   Copyright (C) 2011 eBox Technologies S.L.

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

#include "bwstats.h"
#include <iostream>

using namespace std;

/* BWStats */

void BWStats::addInternalNet(in_addr_t ip, in_addr_t mask) {
    struct network net;
    net.ip = ip && mask;
    net.mask = mask;
    inets.push_back(net);
}

void BWStats::addPacket(const struct ip* ip) {
    in_addr_t src = ip->ip_src.s_addr;
    in_addr_t dst = ip->ip_dst.s_addr;
    if (isInternal(src)) {
        getHost(src)->addPacket(ip);
    }
    if (isInternal(dst)) {
        getHost(dst)->addPacket(ip);
    }
}

bool BWStats::isInternal(in_addr_t ip) {
    for (netvector::iterator net = inets.begin(); net != inets.end(); ++net) {
        if (net->ip == ip && net->mask) {
            return true;
        }
    }
    return false;
}

HostStats* BWStats::getHost(in_addr_t ip) {
    hostsmap::iterator it = data.find(ip);
    if (it == data.end()) {
        // create host
        data[ip] = new HostStats();
    }
    return data[ip];
}


/* HostStats */
void HostStats::addPacket(const struct ip* ip) {
    in_addr_t src = ip->ip_src.s_addr;
    in_addr_t dst = ip->ip_dst.s_addr;
    // TODO update counters
    if (isInternal(src)) {
    }
    if (isInternal(dst)) {
    }
}



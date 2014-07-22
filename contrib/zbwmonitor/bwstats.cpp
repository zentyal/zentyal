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

#include "bwstats.h"
#include <iostream>
#include <string.h>

using namespace std;

/* BWStats */

void BWStats::addInternalNet(in_addr_t ip, in_addr_t mask) {
    struct network net;
    net.ip = ip & mask;
    net.mask = mask;
    inets.push_back(net);
}

void BWStats::addPacket(const struct ip* ip) {
    in_addr_t src = ip->ip_src.s_addr;
    in_addr_t dst = ip->ip_dst.s_addr;
    bool srcInt = isInternal(src);
    bool dstInt = isInternal(dst);

    // account traffic depending on source and destination
    if (srcInt) {
        if (dstInt) getHost(src)->addIntPacket(ip);
        else        getHost(src)->addExtPacket(ip);
    }
    if (dstInt) {
        if (srcInt) getHost(dst)->addIntPacket(ip);
        else        getHost(dst)->addExtPacket(ip);
    }
}

bool BWStats::isInternal(in_addr_t ip) {
    for (netvector::iterator net = inets.begin(); net != inets.end(); ++net) {
        if (net->ip == (ip & net->mask)) {
            return true;
        }
    }
    return false;
}

HostStats* BWStats::getHost(in_addr_t ip) {
    hostsmap::iterator it = data.find(ip);
    if (it == data.end()) {
        // create host
        data[ip] = new HostStats(ip);
    }
    return data[ip];
}

void BWStats::dump(IBWStatsDumper *dumper) {
    hostsmap::iterator it;
    for (it=data.begin(); it != data.end(); it++) {
        dumper->dumpHost(it->second);
    }
}

void BWStats::clear() {
    hostsmap::iterator it;
    for (it=data.begin(); it != data.end(); it++) {
        delete (it->second);
    }
    data.clear();
}


/* HostStats */

HostStats::HostStats(in_addr_t host) {
    ip.s_addr = host;
}

void HostStats::addIntPacket(const struct ip* ipp) {
    addPacket(ipp, &internal);
}

void HostStats::addExtPacket(const struct ip* ipp) {
    addPacket(ipp, &external);
}

void HostStats::addPacket(const struct ip* ipp, BWSummary *sum) {
    in_addr_t src = ipp->ip_src.s_addr;
    in_addr_t dst = ipp->ip_dst.s_addr;
    long len = ntohs(ipp->ip_len);

    sum->numPackets++;
    if (src == ip.s_addr) sum->totalSent += len;
    if (dst == ip.s_addr) sum->totalRecv += len;

    switch (ipp->ip_p) {
        case 6: // TCP
            sum->TCP += len;
            break;

        case 17: // UDP
            sum->UDP += len;
            break;

        case 1: // ICMP
            sum->ICMP += len;
            break;
    }
}


/* BWSummary */
BWSummary::BWSummary() {
    totalRecv = 0;
    totalSent = 0;
    numPackets = 0;

    TCP = 0;
    UDP = 0;
    ICMP= 0;
}


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

#if !defined(BWSTATS)
#define BWSTATS

#include <netinet/ip.h>
#include <map>
#include <vector>

using namespace std;

/* Bandwidth usage container */
class BWSummary {
  public:
    BWSummary();
    void addPacket(const struct ip* ip);

    unsigned long long totalRecv;
    unsigned long long totalSent;
    unsigned long long numPackets;
    // per protocol:
    unsigned long long TCP;
    unsigned long long UDP;
    unsigned long long ICMP;
};


/* Bandwidth usage stats for a IP */
class HostStats {
  public:
    // Constructor
    HostStats(in_addr_t ip);

    // Add internal traffic package to this host
    void addIntPacket(const struct ip* ipp);

    // Add external traffic package to this host
    void addExtPacket(const struct ip* ipp);

    in_addr getIP() { return ip; }
    BWSummary* getInternalBW() { return &internal; }
    BWSummary* getExternalBW() { return &external; }

  private:
    in_addr ip;

    // summarize packet data into internal or external holder
    void addPacket(const struct ip* ipp, BWSummary* sum);

    // Internal and external traffic
    BWSummary internal;
    BWSummary external;
};

// network struct
struct network {
    in_addr_t ip;
    in_addr_t mask;
};

// hosts map
typedef map<in_addr_t, HostStats*> hostsmap;

// Vector of networks
typedef vector<network> netvector;

// Stats dumper interface
class IBWStatsDumper
{
  public:
    virtual void dumpHost(HostStats *host) = 0;
};


/* Bandwidth stats store for all the clients */
class BWStats {
  public:
    // Add the network to the internal networks list
    void addInternalNet(in_addr_t ip, in_addr_t mask);

    // Process the packet and summarize it
    void addPacket(const struct ip* ip);

    // Dump current stats using the given dumper
    void dump(IBWStatsDumper *dumper);

    // Remove all known hosts (reset counters)
    void clear();

  private:
    // returns a pointer to a host (creates it if doesn't exists)
    HostStats* getHost(in_addr_t ip);

    // returns true if the given ip belongs to an internal network
    bool isInternal(in_addr_t ip);

    // <IP -> stats> map
    hostsmap data;

    // Internal networks (to distingish internal and external traffic)
    vector<struct network> inets;
};


#endif


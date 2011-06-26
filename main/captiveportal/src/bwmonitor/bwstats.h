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

#include <netinet/ip.h>
#include <map>
#include <vector>

using namespace std;

/* Bandwidth usage container */
class BWSummary {
  public:
    void addPacket(const struct ip* ip);

    unsigned long long totalSent;
    unsigned long long totalRecv;
    // per protocol:
    unsigned long long TCP;
    unsigned long long UDP;
    unsigned long long ICMP;
};


/* Bandwidth usage stats for a IP */
class HostStats {
  public:
    void addPacket(const struct ip* ip);

  private:
    in_addr ip;

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

/* Bandwidth stats store for all the clients */
class BWStats {
  public:
    // Add the network to the internal networks list
    void addInternalNet(in_addr_t ip, in_addr_t mask);

    // Process the packet and summarize it
    void addPacket(const struct ip* ip);

  private:
    // returns a pointer to a host (creates it if doesn't exists)
    HostStats* getHost(in_addr_t ip);

    bool isInternal(in_addr_t ip);

    // <IP -> stats> map
    hostsmap data;

    // Internal networks (to distingish internal and external traffic)
    vector<struct network> inets;
};


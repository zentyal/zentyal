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

using namespace std;


/* Bandwidth usage container */
class BWSummary {
  public:
    void addPacket(struct ip*);
  private:
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
    void addPacket(struct ip*);

  private:
    in_addr ip;

    // Internal and external traffic
    BWSummary internal;
    BWSummary external;
};


// hosts map
typedef map<in_addr, HostStats> hostsmap;

/* Bandwidth stats store for all the clients */
class BWStats {
  public:
    BWStats();
    void addPacket(struct ip*);

  private:
    // <IP -> stats> map
    hostsmap data;
};



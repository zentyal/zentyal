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
#include <iostream>
#include <pcap.h>
#include <time.h>
#include <netinet/ether.h>
#include <netinet/ip.h>
#include <arpa/inet.h>
#include "bwstats.h"
#include "dumpers/console.h"

#define DEBUG 0

using namespace std;

char ERROR_BUF[PCAP_ERRBUF_SIZE];

// Miliseconds between packets copy op from kernel
const int TO_MS = 1000;

// Packet capture size (big enough to decode headers)
const int CAPTURE_SIZE = 64;

// Dump stats each X seconds
const int DUMP_RATE = 2;

// Global packet stats
BWStats stats;

// Dump result (by now here, of course this is dummy)
ConsoleBWStatsDumper dumper;


// Process a packet, update counters and store valuable info
void processPkt(u_char *useless, const struct pcap_pkthdr* pkthdr, const u_char* packet)
{
    static int count = 1;
    static int lastDump = time(NULL);
    count++;

    if ((time(NULL) - lastDump) > DUMP_RATE) {
        // Dump current status
        // This should not take too long
        // if it does some problems will appear (packet loss)
        stats.dump(&dumper);
        lastDump = time(NULL);
    }

    const struct ether_header *eth;
    const struct ip *ip;
    eth = (const struct ether_header*) packet;
    packet += sizeof(struct ether_header);
    ip = (const struct ip*) packet;

    if (ip->ip_v != 4) return; // TODO IPv6 support

    stats.addPacket(ip);

#if DEBUG
    char src_ip[INET_ADDRSTRLEN];
    char dst_ip[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &(ip->ip_src), src_ip, INET_ADDRSTRLEN);
    inet_ntop(AF_INET, &(ip->ip_dst), dst_ip, INET_ADDRSTRLEN);

    cout << "Counter: " << count << endl;
    cout << "MAC source: " << ether_ntoa((const ether_addr*)eth->ether_shost) << endl;
    cout << "MAC dest: " << ether_ntoa((const ether_addr*)eth->ether_dhost) << endl;
    cout << "IP version: " << ip->ip_v << endl;
    cout << "IP src: " << src_ip << endl;
    cout << "IP dest: " << dst_ip << endl;
    cout << "Size: " << ntohs(ip->ip_len) << endl;
    cout << "Protocol: ";
    switch (ip->ip_p) {
        case 6:
            cout << "TCP";
            break;
        case 17:
            cout << "UDP";
            break;
        case 1:
            cout << "ICMP";
            break;
        default:
            cout << "OTHER";
    }
    cout << endl;
    cout << "--------" << endl;
#endif //DEBUG
}

int main ()
{
    // Setup stats object conf
    stats.addInternalNet(inet_addr("192.168.1.0"), inet_addr("255.255.255.0"));

    // Get available devices
    pcap_if_t* alldevs;
    if (pcap_findalldevs(&alldevs, ERROR_BUF) < 0) {
        perror("pcap_findalldevs");
        return 1;
    }

    // keep first dev to listen there
    string dev = alldevs->name;
    dev = "wlan0";

    cout << "Available devices:" << endl;
    while(alldevs) {
        cout << " - " << alldevs->name << endl;
        alldevs = alldevs->next;
    }

    // Enable capture on the device
    // TODO take into account other layers than ethernet (WiFi, PPoE?)
    cout << "Listening on " << dev << endl;
    pcap_t* descr = pcap_open_live(dev.c_str(), CAPTURE_SIZE, 0, TO_MS, ERROR_BUF);

    // Configure the filter
    // Capture everything and pass it to the handler
    // TODO filter per vlan (vlan 1 or vlan2 or...)
    struct bpf_program fp;
    bpf_u_int32 netp;
    bpf_u_int32 maskp;
    pcap_lookupnet(dev.c_str(), &netp, &maskp, ERROR_BUF);
    if (pcap_compile(descr, &fp, "ip", 0, netp) < 0) {
        perror("pcap_compile");
        return 1;
    }

    if (pcap_setfilter(descr, &fp) < 0) {
        perror("pcap_setfilter");
        return 1;
    }

    pcap_loop(descr, -1, processPkt, NULL);

    return 0;
}


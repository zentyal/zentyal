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
#include <iostream>
#include <pcap.h>
#include <time.h>
#include <netinet/ether.h>
#include <netinet/ip.h>
#include <arpa/inet.h>
#include "bwstats.h"
#include "dumpers/console.h"
#include <libconfig.h>

#define DEBUG 0

using namespace std;

char ERROR_BUF[PCAP_ERRBUF_SIZE];

// Miliseconds between packets copy op from kernel
const int TO_MS = 1000;

// Packet capture size (big enough to decode headers)
const int CAPTURE_SIZE = 64;

// Dump stats each X seconds
int DUMP_RATE = 600;

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
        stats.clear();
        lastDump = time(NULL);
    }

    //const struct ether_header *eth;
    const struct ip *ip;
    //eth = (const struct ether_header*) packet;
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

int main (int argc,char *argv[])
{
    config_t config;

    // Process conf file
    if (argc != 2) {
        cerr << "A parameter is required: configuration file" << endl;
        return 1;
    }

    // Init config
    config_init(&config);
    if (!config_read_file(&config, argv[1])) {
        cerr << config_error_line(&config) << " - ";
        cerr << config_error_text(&config) << endl;
        config_destroy(&config);
        return 1;
    }

    // Device to listen on
    const char *dev = NULL;
    config_lookup_string(&config, "dev", &dev);

    // Dump rate (optional)
    config_lookup_int(&config, "dump_rate", &DUMP_RATE);

    // Configure internal networks
    config_setting_t *networks = config_lookup(&config, "internal_networks");
    if (networks == NULL) {
        cerr << "internal_networks parameter is required in config file!" << endl;
        return 1;
    }

    config_setting_t *network;
    int i=0;
    while ((network = config_setting_get_elem(networks, i++)) != NULL) {
        const char *ip, *mask;
        ip = config_setting_get_string_elem(network, 0);
        mask = config_setting_get_string_elem(network, 1);
        cout << "Adding " << ip << "/" << mask << " as internal network" << endl;
        stats.addInternalNet(inet_addr(ip), inet_addr(mask));
    }


    // Enable capture on the device
    // TODO take into account other layers than ethernet (WiFi, PPoE?)
    cout << "Listening on " << dev << endl;
    pcap_t* descr = pcap_open_live(dev, CAPTURE_SIZE, 0, TO_MS, ERROR_BUF);

    if (descr == NULL) {
        cerr << "Error opening " << dev << ". Are you root?" << endl;
        return 1;
    }

    // Configure the filter
    // Capture everything and pass it to the handler
    // TODO filter per vlan (vlan 1 or vlan2 or...)
    struct bpf_program fp;
    bpf_u_int32 netp;
    bpf_u_int32 maskp;
    pcap_lookupnet(dev, &netp, &maskp, ERROR_BUF);
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


#!/usr/bin/python
#
# Copyright (C) 2011-2013 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# Parse a dhcp dump from windows server to extract configuration values

import subprocess, re, yaml, socket
from IPy import IP

ipre = '\\d+\\.\\d+\\.\\d+\\.\\d+'
cmd = 'netsh dhcp server dump'

def export(filepath):
    # Compile reg exps
    server_def = re.compile('Dhcp Server '+ipre+' add scope ('+ipre+') ('+ipre+') "([^"]*)"')
    range_def = re.compile('Dhcp Server '+ipre+' Scope ('+ipre+') Add iprange ('+ipre+') ('+ipre+')')
    reserved_def = re.compile('Dhcp Server '+ipre+' Scope ('+ipre+') Add reservedip ('+ipre+') ([0-9abcdef]+) "(.*)" ".*" ".*"')

    # result
    dhcp_servers = {}

    # local IPs for this machine
    local_ips = [IP(x) for x in socket.gethostbyname_ex('')[2]]

    p = subprocess.Popen(cmd, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    for line in p.stdout:
        match = server_def.match(line)
        if match:
            (network, netmask, name) = match.groups()
            if network not in dhcp_servers:
                dhcp_servers[network] = {}

            Network = IP(network + '/' + netmask)
            for ip in local_ips:
                if ip in Network:
                    dhcp_servers[network]['ip'] = str(ip)

            dhcp_servers[network]['network'] = network
            dhcp_servers[network]['netmask'] = netmask
            dhcp_servers[network]['name'] = name

        match = range_def.match(line)
        if match:
            (network, range_start, range_end) = match.groups()
            if network not in dhcp_servers:
                dhcp_servers[network] = {}
            if 'ranges' not in dhcp_servers[network]:
                dhcp_servers[network]['ranges'] = []
            dhcp_servers[network]['ranges'].append({'from':range_start, 'to':range_end})
            print 'DEBUG: DHCP range for ' + network + ': ' + range_start + '-' + range_end

        match = reserved_def.match(line)
        if match:
            (network, ip, mac, name) = match.groups()
            mac = ":".join(mac[i:i+2] for i in xrange(0, len(mac), 2))
            if network not in dhcp_servers:
                dhcp_servers[network] = {}
            if 'fixed_addrs' not in dhcp_servers[network]:
                dhcp_servers[network]['fixed_addrs'] = []
            dhcp_servers[network]['fixed_addrs'].append({'ip':ip, 'mac':mac, 'name':name})
            print 'DEBUG: DHCP fixed address for ' + ip + ', mac ' + mac + ': ' + name

    dump = yaml.dump(dhcp_servers.values())
    if filepath:
        f = open(filepath, 'w')
        f.write(dump)
        f.close()
    else:
        print dump

if __name__ == "__main__":
    export(None)

#!/usr/bin/python
#
# Copyright (C) 2011 eBox Technologies S.L.
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

import subprocess, re, yaml

ipre = '\\d+\\.\\d+\\.\\d+\\.\\d+'
cmd = 'netsh dhcp server dump'

def export(filepath):
    # Compile reg exps
    server_def = re.compile('Dhcp Server ('+ipre+') add scope ('+ipre+') ('+ipre+') "(.*)" ".*"')
    range_def = re.compile('Dhcp Server ('+ipre+') Scope ('+ipre+') Add iprange ('+ipre+') ('+ipre+')')
    reserved_def = re.compile('Dhcp Server ('+ipre+') Scope ('+ipre+') Add reservedip ('+ipre+') ([0-9abcdef]+) "(.*)" ".*" ".*"')

    # result
    dhcp_servers = {}

    p = subprocess.Popen(cmd, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    for line in p.stdout:
        match = server_def.match(line)
        if match:
            (server_ip, network, netmask, name) = match.groups()
            if network not in dhcp_servers:
                dhcp_servers[network] = {}
            dhcp_servers[network]['network'] = network
            dhcp_servers[network]['netmask'] = netmask
            dhcp_servers[network]['name'] = name
            print 'DEBUG: DHCP server listening on ' + server_ip + ' for ' + network + '-' + netmask + ' ('+name+')'

        match = range_def.match(line)
        if match:
            (server_ip, network, range_start, range_end) = match.groups()
            if network not in dhcp_servers:
                dhcp_servers[network] = {}
                dhcp_servers[network]['ip'] = network
            if 'ranges' not in dhcp_servers[network]:
                dhcp_servers[network]['ranges'] = []
            dhcp_servers[network]['ranges'].append({'from':range_start, 'to':range_end})
            print 'DEBUG: DHCP range for ' + server_ip + ': ' + range_start + '-' + range_end

        match = reserved_def.match(line)
        if match:
            (server_ip, network, ip, mac, name) = match.groups()
            mac = ":".join(mac[i:i+2] for i in xrange(0, len(mac), 2))
            if network not in dhcp_servers:
                dhcp_servers[network] = {}
                dhcp_servers[network]['ip'] = network
            if 'fixed_addrs' not in dhcp_servers[network]:
                dhcp_servers[network]['fixed_addrs'] = []
            dhcp_servers[network]['fixed_addrs'].append({'ip':ip, 'mac':mac, 'name':name})
            print 'DEBUG: DHCP fixed address for ' + ip + ', mac ' + mac + ': ' + name

    f = open(filepath, 'w')
    f.write(yaml.dump(dhcp_servers.values()))
    f.close()

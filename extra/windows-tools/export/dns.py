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

# Parse a dns zone dump from windows server to extract configuration values

import os, re, subprocess, yaml

ipre = '\\d+\\.\\d+\\.\\d+\\.\\d+'
cmd = 'dnscmd /enumzones /primary'
system32 = 'C:\windows\system32' #TODO get this from env

def export(filepath):
    # FIXME: check if dnscmd is present and show
    # message with instructions to install it if not

    # Compile reg exps
    zone_def = re.compile(' ([^ ]*)\s+Primary')
    record_def = re.compile('([^ ]*)\s+(CNAME|A|MX|TXT|SRV)\s+('+ipre+')')

    # result
    zones = []

    p = subprocess.Popen(cmd, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    for zline in p.stdout:
        match = zone_def.match(zline)
        if match:
            zone = match.group(1)

            try:
                os.remove(system32 + '\dns\zentyal.txt')
            except:
                pass

            subprocess.call('dnscmd /zoneexport ' + zone + ' zentyal.txt', stdin=subprocess.PIPE, stdout=subprocess.PIPE)
            file = open(system32 + '\dns\zentyal.txt', 'r')

            records = []
            for line in file:
                match = record_def.match(line)
                if match:
                    (name, type, ip) = match.groups()
                    records.append({ 'name':name, 'type':type, 'ip':ip })
                    print 'DEBUG: ' + name + ' on ' + ip + ' type ' + type

            file.close()
            zones.append({ 'name':zone, 'records':records })

    f = open(filepath, 'w')
    f.write(yaml.dump(zones, default_flow_style=False))
    f.close()


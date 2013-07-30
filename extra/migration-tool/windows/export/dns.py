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
    arecord_def = re.compile('([^ ]*)\s+A\s+('+ipre+')')
    mxrecord_def = re.compile('\s+MX\s+(\d+)\s+(.*)')

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
                match = arecord_def.match(line)
                if match:
                    (name, ip) = match.groups()
                    records.append({ 'name':name, 'type':'A', 'ip':ip })

                match = mxrecord_def.match(line)
                if match:
                    (preference, name) = match.groups()
                    records.append({ 'name':name, 'type':'MX', 'preference': preference})

            file.close()
            zones.append({ 'name':zone, 'records':records })

    dump = yaml.dump(zones, default_flow_style=False)
    if filepath:
        f = open(filepath, 'w')
        f.write(dump)
        f.close()
    else:
        print dump

if __name__ == "__main__":
    export(None)


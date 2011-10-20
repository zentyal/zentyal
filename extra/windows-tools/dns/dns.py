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

import subprocess
import re
import os

# Compile reg exps
zone_def = re.compile(' (.*)\s+Primary')
ipre = '\\d+\\.\\d+\\.\\d+\\.\\d+';

record_def = re.compile('(.*)\s+(CNAME|A|MX|TXT|SRV)\s+('+ipre+')')


system32 = 'C:\windows\system32' #TODO get this from env

cmd = 'dnscmd /enumzones /primary'
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

        for line in file:
            match = record_def.match(line)
            if match:
                name = match.group(1)
                type = match.group(2)
                ip = match.group(3)

                print name + ' on ' + ip + ' type ' + type

        file.close()


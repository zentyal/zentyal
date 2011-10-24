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

import os, yaml, win32security

def get_sid():
    policy_handle = win32security.GetPolicyHandle('', win32security.POLICY_ALL_ACCESS)
    sid = win32security.LsaQueryInformationPolicy(policy_handle, win32security.PolicyDnsDomainInformation)[4]
    sid = str(sid).split(':')[1]
    win32security.LsaClose(policy_handle)
    return sid

def export(filepath):
    data = {}
    data['domain'] = os.getenv('USERDOMAIN')
    data['servername'] = os.getenv('COMPUTERNAME')
    data['sid'] = get_sid()

    dump = yaml.dump(data, default_flow_style=False)
    if filepath:
        f = open(filepath, 'w')
        f.write(dump)
        f.close()
    else:
        print dump

if __name__ == "__main__":
    export(None)


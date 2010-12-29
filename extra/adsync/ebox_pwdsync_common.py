# Copyright (C) 2009-2010 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the Lesser GNU General Public License as
# published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# Lesser GNU General Public License for more details.
#
# You should have received a copy of the Lesser GNU General Public
# License along with This program; if not, write to the
#   Free Software Foundation, Inc.,
#   59 Temple Place, Suite 330,
#   Boston, MA  02111-1307
#   USA

import os
from _winreg import *

NTDS_KEY = 'SYSTEM\\CurrentControlSet\\Services\\NTDS\\Parameters'

def get_queue_path():
    hKey = OpenKey(HKEY_LOCAL_MACHINE, NTDS_KEY, 0, KEY_READ)
    path = QueryValueEx(hKey, 'DSA Working Directory')[0]
    path += '\\ebox-adsync'

    # Create directory if not exists
    if not os.access(path, os.F_OK):
        os.mkdir(path, 0600)

    return path

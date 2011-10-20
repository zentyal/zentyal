# Copyright (C) 2009-2011 eBox Technologies S.L.
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
from ctypes import c_int, WINFUNCTYPE, windll
from ctypes.wintypes import HWND, LPCSTR, UINT

NTDS_KEY = 'SYSTEM\\CurrentControlSet\\Services\\NTDS\\Parameters'
LSA_KEY = 'SYSTEM\\CurrentControlSet\\Control\\Lsa'
REG_DATA = 'Notification Packages'
HOOK_DLL = 'passwdhk'

prototype = WINFUNCTYPE(c_int, HWND, LPCSTR, LPCSTR, UINT)
paramflags = (1, "hwnd", 0), (1, "text", None), (1, "caption", None), (1, "flags", 0)
MessageBox = prototype(("MessageBoxA", windll.user32), paramflags)

def get_queue_path():
    hKey = OpenKey(HKEY_LOCAL_MACHINE, NTDS_KEY, 0, KEY_READ)
    path = QueryValueEx(hKey, 'DSA Working Directory')[0]
    path += '\\ebox-adsync'

    # Create directory if not exists
    if not os.access(path, os.F_OK):
        os.mkdir(path, 0600)

    return path

def set_adsync_status(enable):
    hKey = _open_lsa_key()
    packages = _read_notification_packages(hKey)
    enabled = _is_hook_enabled(packages)
    if enable:
        if enabled:
            MessageBox(text='Zentyal password hook is already registered in the registry',
                       caption='Enabling Zentyal password hook in registry notification packages')
        else:
            packages.append(HOOK_DLL)
            SetValueEx(hKey, REG_DATA, 0, REG_MULTI_SZ, packages)
            MessageBox(text='Zentyal password hook enabled in registry', caption='Success');
    else:
        if enabled:
            packages.remove(HOOK_DLL)
            SetValueEx(hKey, REG_DATA, 0, REG_MULTI_SZ, packages)
            MessageBox(text='Zentyal password hook disabled in registry', caption='Success')
        else:
            MessageBox(text='Zentyal password hook is already disabled in the registry',
                       caption='Disabling Zentyal password hook in registry notification packages')

def get_adsync_status():
    hKey = _open_lsa_key()
    packages = _read_notification_packages(hKey)
    return _is_hook_enabled(packages)

def _open_lsa_key():
    hKey = OpenKey(HKEY_LOCAL_MACHINE, LSA_KEY, 0, KEY_ALL_ACCESS)
    if hKey == None:
        MessageBox(text='ERROR: Failed to open registry key "' + LSA_KEY + '"',
                   caption='Error opening registry key')
    return hKey

def _read_notification_packages(hKey):
    packages = QueryValueEx(hKey, REG_DATA)[0]
    if packages == None:
        MessageBox(text='ERROR: Failed to read "' + REG_DATA + '" from registry',
                   caption='Error reading registry key')
    return packages

def _is_hook_enabled(packages):
    found = HOOK_DLL in (i.lower() for i in packages)
    return found


#!/usr/bin/python
# coding: utf-8
#
# D-BUS daemon that handles the upgrade process from Exchange to OpenChange
#
# OpenChange Project
#
# Copyright (C) Zentyal SL 2013
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

import gobject
import dbus
import dbus.service
import dbus.mainloop.glib
from time import sleep

class Upgrade(dbus.service.Object):

    @dbus.service.method("org.zentyal.openchange.Upgrade",
                         in_signature='', out_signature='s')
    def Run(self):
        import os
        os.system('/home/carlos/Work/zentyal/zentyal-exchange/exchange-tools/build/src/mailboxsize -p kernevil')
        for i in range(100):
            self.PropertyChanged('Foo', 1)
            sleep(0.1)
        return 'OK'

    @dbus.service.method("org.zentyal.openchange.Upgrade",
                         in_signature='', out_signature='s')
    def Cancel(self):
        return "OK"

    @dbus.service.signal("org.zentyal.openchange.Upgrade",
                         signature='su')
    def PropertyChanged(self, property, value):
        pass

if __name__ == '__main__':
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

    system_bus = dbus.SystemBus()
    name = dbus.service.BusName("org.zentyal.openchange.Upgrade", system_bus)
    Upgrade(system_bus, '/org/zentyal/openchange/Upgrade')

    mainloop = gobject.MainLoop()
    print "Running example service."
    mainloop.run()

import gobject, dbus, dbus.mainloop.glib

def muestra(property, value):

    print property
    print value

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

bus = dbus.SystemBus()

bus.add_signal_receiver(muestra, path="/org/zentyal/openchange/Upgrade",
    dbus_interface="org.zentyal.openchange.Upgrade", signal_name ="PropertyChanged")

loop = gobject.MainLoop()

loop.run()

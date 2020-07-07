#!/bin/bash

# Checks if the server is already registered
if [ -f /var/lib/zentyal/ucp-server_data ] && [ -f /var/lib/zentyal/ucp-token ] && [ -f /var/lib/zentyal/.license ]; then
    status=$(/usr/share/zentyal-ucp/21_ucp-link.sh pid)
    # if the linnk has PID
    if [ $status ];
    then
        while [ true ]
        do
            # this scripts logins into the UCP every 50sec aprox
            /usr/share/zentyal-ucp/10_login.sh
            # this script sends a request every 5 seconds to UCP
            /usr/share/zentyal-ucp/30_update-server.sh
        done
    else
        # restart the link
        status=$(/usr/share/zentyal-ucp/21_ucp-link.sh start)
    fi
else
    /usr/share/zentyal-ucp/20_register-server.sh
fi
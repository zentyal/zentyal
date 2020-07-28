#!/bin/bash -x

# saving the pid
echo $$ > /var/run/ucp.pid

# Checks if the server is already registered
if [ -f /var/lib/zentyal/ucp-server_data ] && [ -f /var/lib/zentyal/ucp-token ] && [ -f /var/lib/zentyal/.license ]; then
    status=$(/usr/share/zentyal-ucp/21_ucp-link.sh pid)
    # if the linnk has PID
    if [ $status ];
    then
        # restart the link
        /usr/share/zentyal-ucp/21_ucp-link.sh restart
    else
        # start the link
        /usr/share/zentyal-ucp/21_ucp-link.sh start
    fi

    while [ true ]
    do
        # this scripts logins into the UCP every 50sec aprox
        /usr/share/zentyal-ucp/10_login.sh
        # this script sends a request every 5 seconds to UCP
        /usr/share/zentyal-ucp/30_update-server.sh
    done
else
    /usr/share/zentyal-ucp/10_login.sh
    /usr/share/zentyal-ucp/20_register-server.sh
    /usr/share/zentyal-ucp/21_ucp-link.sh start

    while [ true ]
    do
        /usr/share/zentyal-ucp/10_login.sh
        /usr/share/zentyal-ucp/30_update-server.sh
    done
fi
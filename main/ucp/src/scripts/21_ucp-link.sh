#!/bin/bash

export PATH=/usr/sbin:/usr/bin:/sbin:/bin 

# The remote port where Zentyal is going to be forwarded
PORT=$(cat /var/lib/zentyal/.port)
# The enabled LK for this server
LK=$(cat /var/lib/zentyal/.license) 
# The UUID that is going to be used to the remote login
UUID=$(cat /var/lib/zentyal/.uuid) 
# The cmd to run the tunnel in a random port
cmd="ssh -i /var/lib/zentyal/ucp_rsa -o StrictHostKeyChecking=no -f -R $PORT:localhost:8443 -N ucp@ra.zentyal.com"

# Gets the tunnel PID
function get_pid {
    PID=$(ps aux | grep "$cmd" | grep -v 'grep' | awk '{print $2}')
}

# Stablishes the tunnel if is not already running
function start_tunnel {
    get_pid

    if [[ -n "$PID" ]]; then
        logger UCP-LINK[$$] WARNING: Another tunnel is already running \(pid $PID\)
        exit 1
    fi

    # Stablishing the tunnel and saving the forwarded port
    $cmd

    # getting the new tunnel pid
    get_pid
    logger UCP-LINK[$$] INFO: Started new process: $PID
}

# Stops the running tunnel
function stop_tunnel {
    get_pid

    if [[ -z "$PID" ]]; then
        logger UCP-LINK[$$] WARNING: Couldn\'t find a running tunnel
        exit 2
    fi
 
    oldpid=$PID
    kill $PID
    get_pid

    if [[ -z $PID ]]; then
        logger UCP-LINK[$$] INFO: Killed process $oldpid
    else
        logger UCP-LINK[$$] ERROR: Unable to terminate process $PID
        exit 3
    fi
}

if [[ -n "$1" ]]; then
    action=$1
else
    action='start'
fi

case "$action" in
    start)      start_tunnel ;;
    stop)       stop_tunnel  ;;
    restart)    stop_tunnel
                start_tunnel ;;
    pid)        get_pid
                echo $PID ;;
esac
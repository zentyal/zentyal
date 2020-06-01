#!/bin/bash

export PATH=/usr/sbin:/usr/bin:/sbin:/bin 

# The remote port where Zentyal is going to be forwarded
PORT=$(cat /var/lib/zentyal/.port)
# The enabled LK for this server
LK=$(cat /var/lib/zentyal/.license) 
# The UUID that is going to be used to the remote login
UUID=$(cat /var/lib/zentyal/.uuid) 
# The cmd to run the tunnel in a random port
cmd="ssh -i ucp_rsa -o StrictHostKeyChecking=no -f -R $PORT:localhost:8443 -N ucp@ra.zentyal.com"

# Gets the tunnel PID
function get_pid {
    PID=$(ps aux | grep "$cmd" | grep -v 'grep' | awk '{print $2}')
}

# Stablishes the tunnel if is not already running
function start_tunnel {
    get_pid

    if [[ -n "$PID" ]]; then
        logger UCP-LINK[$$] WARNING: Another tunnel is already running \(pid $PID\)

        # Adapted to Zentyal
        lvl='warn'
        log_string="Another tunnel is already running (pid $PID)"
        zentyal_logger_helper
        # Ends Zentyal adaptation
        exit 1
    fi

    # Stablishing the tunnel and saving the forwarded port
    $cmd

    # getting the new tunnel pid
    get_pid
    logger UCP-LINK[$$] INFO: Started new process: $PID

    # Adapted to Zentyal
    lvl='info'
    log_string="Started new process: $PID"
    zentyal_logger_helper
    # Ends Zentyal adaptation
}

# Stops the running tunnel
function stop_tunnel {
    get_pid

    if [[ -z "$PID" ]]; then
        logger UCP-LINK[$$] WARNING: Couldn\'t find a running tunnel

        # Adapted to Zentyal
        lvl='warn'
        log_string="Couldn\'t find a running tunnel"
        zentyal_logger_helper
        # Ends Zentyal adaptation

        exit 2
    fi
 
    oldpid=$PID
    kill $PID
    get_pid

    if [[ -z $PID ]]; then
        logger UCP-LINK[$$] INFO: Killed process $oldpid

        # Adapted to Zentyal
        lvl='info'
        log_string="Killed process $oldpid"
        zentyal_logger_helper
        # Ends Zentyal adaptation
    else
        logger UCP-LINK[$$] ERROR: Unable to terminate process $PID

         # Adapted to Zentyal
        lvl='erro'
        log_string="Unable to terminate process $PID"
        zentyal_logger_helper
        # Ends Zentyal adaptation

        exit 3
    fi
}

function zentyal_logger_helper {
    if [ -f '/var/log/zentyal/zentyal.log' ]; then
        case $lvl in
            info) str="my \$log = '$log_string'; EBox::info(\$log)";;
            warn) str="my \$log = '$log_string'; EBox::warn(\$log)";;
            erro) str="my \$log = '$log_string'; EBox::error(\$log)";;
        esac
        /usr/share/zentyal/shell "$str"
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